import Foundation
import Supabase
import SwiftData

@MainActor
final class SyncService {
    static let shared = SyncService()

    private let client = SupabaseManager.shared.client
    private let pendingSyncKey = "parlance.pendingSync"

    private init() {}

    // MARK: - Profile fetch (called on sign-in when local user may or may not exist)

    /// Pulls the Supabase profile + stats and reconciles with the local
    /// SwiftData User. If the local user does not yet exist, a new one is
    /// created from the server profile. If the local user already exists
    /// (e.g. the user signed up offline, practiced, then connected), we
    /// **merge** rather than overwrite — XP, streak, and best-streak take
    /// the larger of (local, server) so offline practice is never lost.
    /// The previous behavior unconditionally clobbered local stats with
    /// server stats, which destroyed offline-first practice progress.
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

            let persistence = PersistenceService.shared
            let user: User
            if let existing = persistence.getUser(uid: uid) {
                // Merge profile descriptors: prefer non-empty server values
                // (display name, username) but never erase a local value the
                // user typed during offline setup.
                if !profile.displayName.isEmpty { existing.displayName = profile.displayName }
                if !profile.username.isEmpty { existing.username = profile.username }
                existing.location = profile.location ?? existing.location
                existing.occupation = profile.occupation ?? existing.occupation
                if !profile.avatarEmoji.isEmpty { existing.avatarEmoji = profile.avatarEmoji }
                if let remoteAvatarURL = profile.avatarUrl { existing.avatarUrl = remoteAvatarURL }
                if let remoteStamp = profile.avatarUpdatedAt { existing.avatarUpdatedAt = remoteStamp }
                if let stats {
                    existing.xp = max(existing.xp, stats.xp)
                    existing.currentStreak = max(existing.currentStreak, stats.currentStreak)
                    existing.longestStreak = max(existing.longestStreak, stats.longestStreak)
                }
                try? persistence.context.save()
                user = existing
            } else {
                user = persistence.createUser(
                    supabaseUID: uid,
                    name: profile.displayName,
                    username: profile.username,
                    location: profile.location,
                    occupation: profile.occupation,
                    avatar: profile.avatarEmoji,
                    avatarUrl: profile.avatarUrl,
                    avatarUpdatedAt: profile.avatarUpdatedAt,
                    practiceLevel: 5
                )
                if let stats {
                    user.xp = stats.xp
                    user.currentStreak = stats.currentStreak
                    user.longestStreak = stats.longestStreak
                    try? persistence.context.save()
                }
            }

            // One-shot avatar back-fill — user has a local photo but no remote avatar yet.
            if profile.avatarUrl == nil, let localData = user.profileImageData {
                let uidForUpload = user.supabaseUID
                Task {
                    do {
                        let path = try await AvatarService.shared.uploadAvatar(originalData: localData, userId: uidForUpload)
                        let stamp = try await AvatarService.shared.updateProfileAvatar(userId: uidForUpload, path: path)
                        await MainActor.run {
                            user.avatarUrl = path
                            user.avatarUpdatedAt = stamp
                            try? PersistenceService.shared.context.save()
                        }
                    } catch {
                        // Silent — next launch retries.
                    }
                }
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

    func syncAfterSession(clientSessionId: UUID, score: Int, mode: SessionMode, level: Int) async {
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
        do {
            try await client.from("user_stats").upsert(stats).execute()
            // Real Life sessions count for XP/streak/global stats above, but are
            // excluded from session_scores (the leaderboard feed) to prevent
            // prompt-gamed scoring.
            if mode != .realLife {
                let scoreRow = SessionScoreRow(
                    userId: authUser.id,
                    clientSessionId: clientSessionId,
                    score: score,
                    mode: mode.rawValue,
                    level: level
                )
                try await client.from("session_scores")
                    .upsert(scoreRow, onConflict: "user_id,client_session_id")
                    .execute()
            }
            removePendingSync(clientSessionId: clientSessionId)
        } catch {
            #if DEBUG
            print("[SyncService] syncAfterSession failed, queuing: \(error)")
            #endif
            enqueuePendingSync(clientSessionId: clientSessionId, score: score, mode: mode.rawValue, level: level)
        }
    }

    /// Drain the offline queue head-first. Each pending sync re-enters
    /// `syncAfterSession`, which removes the entry on success or re-queues
    /// on failure. Stops at the first failure so we don't spin against a
    /// broken upstream.
    func flushPendingSync() async {
        let queue = loadPendingSyncQueue()
        for pending in queue {
            guard let mode = SessionMode(rawValue: pending.mode) else {
                removePendingSync(clientSessionId: pending.clientSessionId)
                continue
            }
            let before = loadPendingSyncQueue().count
            await syncAfterSession(
                clientSessionId: pending.clientSessionId,
                score: pending.score,
                mode: mode,
                level: pending.level
            )
            let after = loadPendingSyncQueue().count
            // Stop if syncAfterSession didn't drain this entry — i.e. the
            // upstream is still failing — so we don't burn through retries
            // for nothing on every call.
            if after >= before { break }
        }
    }

    func flushIfNeeded() async {
        guard !loadPendingSyncQueue().isEmpty else { return }
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

    // MARK: - Preference sync

    func syncDailyReminderEnabled(_ enabled: Bool) async {
        guard let authUser = client.auth.currentUser else { return }
        do {
            try await client.from("profiles")
                .update(["daily_reminder_enabled": enabled])
                .eq("id", value: authUser.id)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] syncDailyReminderEnabled failed: \(error)")
            #endif
        }
    }

    // MARK: - Offline queue
    //
    // Persisted as a FIFO array of `PendingSync` under `pendingSyncKey`.
    // Previously this slot held exactly one PendingSync, so a second offline
    // session silently overwrote the first. With per-session idempotency
    // enforced server-side by the `session_scores (user_id, client_session_id)`
    // unique constraint, queuing every offline session is safe — replays
    // upsert without duplicating rows.
    //
    // For back-compat, `loadPendingSyncQueue` accepts both the new array
    // shape and the legacy single-object shape so a user upgrading mid-flight
    // doesn't lose their pre-existing queued session.

    private struct PendingSync: Codable {
        let clientSessionId: UUID
        let score: Int
        let mode: String
        let level: Int
    }

    private func enqueuePendingSync(clientSessionId: UUID, score: Int, mode: String, level: Int) {
        var queue = loadPendingSyncQueue()
        // Drop any prior entry with the same client_session_id so a flapping
        // upstream doesn't multiply rows. Idempotent in spirit.
        queue.removeAll { $0.clientSessionId == clientSessionId }
        queue.append(PendingSync(clientSessionId: clientSessionId, score: score, mode: mode, level: level))
        savePendingSyncQueue(queue)
    }

    private func removePendingSync(clientSessionId: UUID) {
        var queue = loadPendingSyncQueue()
        queue.removeAll { $0.clientSessionId == clientSessionId }
        if queue.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingSyncKey)
        } else {
            savePendingSyncQueue(queue)
        }
    }

    private func loadPendingSyncQueue() -> [PendingSync] {
        guard let data = UserDefaults.standard.data(forKey: pendingSyncKey) else { return [] }
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([PendingSync].self, from: data) {
            return array
        }
        // Legacy single-object payload from before the FIFO migration.
        if let single = try? decoder.decode(PendingSync.self, from: data) {
            return [single]
        }
        return []
    }

    private func savePendingSyncQueue(_ queue: [PendingSync]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: pendingSyncKey)
        }
    }
}
