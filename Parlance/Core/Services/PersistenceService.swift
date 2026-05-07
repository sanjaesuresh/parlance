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
        } catch {
            // Persistent store failed (e.g. schema migration after an update).
            // Fall back to in-memory so the app stays alive; data won't persist this session.
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Failed to create ModelContainer (persistent and in-memory): \(error)")
            }
        }
    }

    static func inMemory() -> ModelContainer {
        let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    var context: ModelContext { container.mainContext }

    // MARK: - User

    func getUser() -> User? {
        let descriptor = FetchDescriptor<User>()
        return try? context.fetch(descriptor).first
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
        let calendar = Calendar.current
        let now = Date.now
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let predicate = #Predicate<Session> { $0.date >= weekStart }
        let descriptor = FetchDescriptor<Session>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
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
        let existing = getAchievements()
        guard existing.isEmpty else { return }
        for def in Achievement.definitions {
            let achievement = Achievement(
                id: def.id, name: def.name,
                descriptionText: def.description, iconName: def.icon, goal: def.goal
            )
            context.insert(achievement)
        }
        try? context.save()
    }

    func unlockAchievement(id: String) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }),
              !achievement.isUnlocked else { return }
        achievement.isUnlocked = true
        achievement.unlockedDate = .now
        achievement.progress = achievement.goal
        try? context.save()
    }

    func updateAchievementProgress(id: String, progress: Int) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }) else { return }
        achievement.progress = min(progress, achievement.goal)
        if achievement.progress >= achievement.goal && !achievement.isUnlocked {
            achievement.isUnlocked = true
            achievement.unlockedDate = .now
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
