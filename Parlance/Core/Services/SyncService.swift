import Foundation
import Supabase

@MainActor
final class SyncService {
    static let shared = SyncService()

    private let client = SupabaseManager.shared.client
    private let pendingSyncKey = "parlance.pendingSync"

    private init() {}

    // MARK: - Profile creation (called once from FirstLaunchSetupView)

    func createProfile(for user: User, authService: AuthService) async {
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
        do {
            try await client.from("profiles").insert(profile).execute()
            try await client.from("user_stats").insert(stats).execute()
        } catch {
            #if DEBUG
            print("[SyncService] createProfile failed: \(error)")
            #endif
        }
    }

    // MARK: - Post-session sync

    func syncAfterSession(score: Int, mode: SessionMode, level: Int) async {
        guard let authUser = client.auth.currentUser else { return }
        let persistence = PersistenceService.shared
        guard let user = persistence.getUser() else { return }

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

    // MARK: - Static helpers (testable)

    static func sumXP(_ values: [Int]) -> Int {
        values.reduce(0, +)
    }

    static func average(scores: [Int]) -> Int {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
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
