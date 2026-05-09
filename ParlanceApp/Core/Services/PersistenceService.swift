import Foundation
import SwiftData

@MainActor
final class PersistenceService {
    static let shared = PersistenceService()

    let container: ModelContainer

    private init() {
        let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
        let persistentConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [persistentConfig])
            UserDefaults.standard.removeObject(forKey: "parlance.store_wiped")
        } catch let firstError {
            // Migration failed — wipe the store and recreate fresh rather than silently
            // falling back to in-memory (which causes sessions to vanish on restart).
            print("[PersistenceService] Persistent store failed, wiping: \(firstError)")
            Self.wipePersistentStore()
            UserDefaults.standard.set(true, forKey: "parlance.store_wiped")
            do {
                container = try ModelContainer(for: schema, configurations: [persistentConfig])
            } catch {
                fatalError("[PersistenceService] Store unrecoverable after wipe: \(error)")
            }
        }
    }

    private static func wipePersistentStore() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let contents = try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil) else { return }
        for url in contents {
            let name = url.lastPathComponent
            if name.hasSuffix(".store") || name.hasSuffix(".store-shm") || name.hasSuffix(".store-wal") {
                try? fm.removeItem(at: url)
            }
        }
    }

    static func inMemory() -> ModelContainer {
        let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    // For unit tests only — creates an isolated in-memory instance separate from shared
    static func forTesting() -> PersistenceService {
        PersistenceService(container: inMemory())
    }

    private init(container: ModelContainer) {
        self.container = container
    }

    var context: ModelContext { container.mainContext }

    // MARK: - User

    func getUser() -> User? {
        let descriptor = FetchDescriptor<User>()
        return try? context.fetch(descriptor).first
    }

    func getUser(uid: String) -> User? {
        guard !uid.isEmpty else { return nil }
        let descriptor = FetchDescriptor<User>()
        return try? context.fetch(descriptor).first { $0.supabaseUID == uid }
    }

    func createUser(supabaseUID: String, name: String, username: String = "", location: String? = nil, occupation: String? = nil, avatar: String, practiceLevel: Int = 1) -> User {
        let user = User(supabaseUID: supabaseUID, displayName: name, username: username, location: location, occupation: occupation, avatarEmoji: avatar, practiceLevel: practiceLevel, hasCompletedSetup: true)
        context.insert(user)
        try? context.save()
        return user
    }

    // MARK: - Sessions

    func saveSession(_ session: Session) {
        context.insert(session)
        try? context.save()
    }

    func recentSessions(limit: Int = 16) -> [Session] {
        var descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func sessionsThisWeek() -> [Session] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.date >= weekStart }
    }

    func totalSessionCount() -> Int {
        let descriptor = FetchDescriptor<Session>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func interviewSessionCount() -> Int {
        let modeRaw = SessionMode.interview.rawValue
        let predicate = #Predicate<Session> { $0.modeRaw == modeRaw }
        let descriptor = FetchDescriptor<Session>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Achievements

    func getAchievements() -> [Achievement] {
        let descriptor = FetchDescriptor<Achievement>(sortBy: [SortDescriptor(\.id)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func seedAchievementsIfNeeded() {
        let key = "parlance.achievements_seeded"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let existing = getAchievements()
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        for def in Achievement.definitions {
            let achievement = Achievement(
                id: def.id, name: def.name,
                descriptionText: def.description, iconName: def.icon, goal: def.goal
            )
            context.insert(achievement)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    func unlockAchievement(id: String) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }),
              !achievement.isUnlocked else { return }
        achievement.isUnlocked = true
        achievement.unlockedDate = .now
        achievement.progress = achievement.goal
        try? context.save()
        AnalyticsService.achievementUnlocked(id: id, name: achievement.name)
    }

    func updateAchievementProgress(id: String, progress: Int) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }) else { return }
        achievement.progress = min(progress, achievement.goal)
        if achievement.progress >= achievement.goal && !achievement.isUnlocked {
            achievement.isUnlocked = true
            achievement.unlockedDate = .now
            AnalyticsService.achievementUnlocked(id: id, name: achievement.name)
        }
        try? context.save()
    }

    // MARK: - Seen Questions

    func markQuestionSeen(questionId: String, mode: SessionMode, band: String) {
        let seen = SeenQuestion(questionId: questionId, mode: mode, difficultyBand: band)
        context.insert(seen)
        try? context.save()
    }

    func seenQuestionIds(mode: SessionMode, band: String) -> Set<String> {
        let modeRaw = mode.rawValue
        let predicate = #Predicate<SeenQuestion> {
            $0.modeRaw == modeRaw && $0.difficultyBand == band
        }
        var descriptor = FetchDescriptor<SeenQuestion>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.seenAt, order: .reverse)]
        )
        descriptor.fetchLimit = AppConstants.seenQuestionWindow
        let results = (try? context.fetch(descriptor)) ?? []
        return Set(results.map(\.questionId))
    }

    // MARK: - Reset

    func resetAllData() {
        try? context.delete(model: Session.self)
        try? context.delete(model: Achievement.self)
        try? context.delete(model: SeenQuestion.self)
        try? context.delete(model: User.self)
        try? context.save()
    }
}
