import Foundation
import Supabase
import SwiftData

@MainActor
final class SyncService {
    static let shared = SyncService()

    private let client = SupabaseManager.shared.client
    private let pendingSyncKey = "parlance.pendingSync"

    private init() {}

    // MARK: - Profile fetch (called on sign-in when no local user exists)

    func fetchAndImportProfile(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let profile: ProfileRow = try await client
                .from("profiles")
                .select()
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            let stats: UserStatsRow? = try? await client
                .from("user_stats")
                .select()
                .eq("user_id", value: uid)
                .single()
                .execute()
                .value

            let user = PersistenceService.shared.createUser(
                supabaseUID: uid,
                name: profile.displayName,
                username: profile.username,
                location: profile.location,
                occupation: profile.occupation,
                avatar: profile.avatarEmoji,
                practiceLevel: 5
            )
            if let stats {
                user.xp = stats.xp
                user.currentStreak = stats.currentStreak
                user.longestStreak = stats.longestStreak
                try? PersistenceService.shared.context.save()
            }
        } catch {
            #if DEBUG
            print("[SyncService] fetchAndImportProfile: no profile found for \(uid): \(error)")
            #endif
        }
    }

    // MARK: - Profile creation (called once from FirstLaunchSetupView)

    func createProfile(for user: User, authService: AuthService) async throws {
        guard let authUser = authService.currentUser else { return }
        let profile = NewProfile(
            id: authUser.id,
            displayName: user.displayName,
            username: user.username ?? "",
            avatarEmoji: user.avatarEmoji,
            location: user.location,
            occupation: user.occupation
        )
        let stats = UserStatsRow(
            userId: authUser.id,
            xp: 0, weeklyXP: 0, currentStreak: 0,
            longestStreak: 0, avgScore: 0, totalSessions: 0,
            lastSessionAt: nil
        )
        try await client.from("profiles").upsert(profile, onConflict: "id").execute()
        try await client.from("user_stats").upsert(stats, onConflict: "user_id").execute()
    }

    // MARK: - Post-session sync

    func syncAfterSession(score: Int, mode: SessionMode, level: Int) async {
        guard let authUser = client.auth.currentUser else { return }
        let persistence = PersistenceService.shared
        guard let user = persistence.getUser(uid: authUser.id.uuidString) else { return }

        let weeklySessions = persistence.sessionsThisWeek()
        let allSessions = persistence.recentSessions(limit: 9999)
        let weeklyXP = Self.sumXP(weeklySessions.map(\.xpEarned))
        let avgScore = Self.average(scores: allSessions.map(\.overallScore))

        let stats = UserStatsRow(
            userId: authUser.id,
            xp: user.xp,
            weeklyXP: weeklyXP,
            currentStreak: user.currentStreak,
            longestStreak: user.longestStreak,
            avgScore: avgScore,
            totalSessions: allSessions.count,
            lastSessionAt: Date()
        )
        let scoreRow = SessionScoreRow(
            userId: authUser.id,
            score: score,
            mode: mode.rawValue,
            level: level
        )

        do {
            try await client.from("user_stats").upsert(stats).execute()
            try await client.from("session_scores").insert(scoreRow).execute()
            clearPendingSync()
        } catch {
            #if DEBUG
            print("[SyncService] syncAfterSession failed, queuing: \(error)")
            #endif
            storePendingSync(score: score, mode: mode.rawValue, level: level)
        }
    }

    func flushPendingSync() async {
        guard let pending = loadPendingSync(),
              let mode = SessionMode(rawValue: pending.mode) else { return }
        await syncAfterSession(score: pending.score, mode: mode, level: pending.level)
    }

    func flushIfNeeded() async {
        guard loadPendingSync() != nil else { return }
        await flushPendingSync()
    }

    // MARK: - Static helpers (testable)

    nonisolated static func sumXP(_ values: [Int]) -> Int {
        values.reduce(0, +)
    }

    nonisolated static func average(scores: [Int]) -> Int {
        guard !scores.isEmpty else { return 0 }
        let sum = scores.reduce(0, +)
        return Int((Double(sum) / Double(scores.count)).rounded())
    }

    // MARK: - Offline queue

    private struct PendingSync: Codable {
        let score: Int
        let mode: String
        let level: Int
    }

    private func storePendingSync(score: Int, mode: String, level: Int) {
        let pending = PendingSync(score: score, mode: mode, level: level)
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingSyncKey)
        }
    }

    private func loadPendingSync() -> PendingSync? {
        guard let data = UserDefaults.standard.data(forKey: pendingSyncKey) else { return nil }
        return try? JSONDecoder().decode(PendingSync.self, from: data)
    }

    private func clearPendingSync() {
        UserDefaults.standard.removeObject(forKey: pendingSyncKey)
    }
}
