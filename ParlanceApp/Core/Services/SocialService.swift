import Foundation
import Combine
import Supabase

enum RelationshipState {
    case none
    case pendingSent
    case pendingReceived
    case friends
    case isSelf
}

@MainActor
final class SocialService: ObservableObject {
    @Published private(set) var friendsLeaderboard: [SocialProfile] = []
    @Published private(set) var pendingRequestCount: Int = 0
    @Published private(set) var blockedUserIds: Set<UUID> = []

    private let client = SupabaseManager.shared.client

    var currentUserId: UUID? { client.auth.currentUser?.id }

    // MARK: - User search

    func searchUsers(query: String) async -> [PublicProfile] {
        let safe = query.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            .trimmingCharacters(in: .whitespaces)
        guard !safe.isEmpty, currentUserId != nil else { return [] }
        do {
            struct SearchParams: Encodable { let q: String }
            let rows: [PublicProfileRow] = try await client
                .rpc("search_public_profiles", params: SearchParams(q: safe))
                .execute()
                .value
            return rows
                .map { $0.asPublicProfile() }
                .filter { !blockedUserIds.contains(UUID(uuidString: $0.id) ?? UUID()) }
        } catch {
            return []
        }
    }

    // MARK: - Leaderboard

    func fetchFriendsLeaderboard() async {
        guard let currentId = currentUserId else { friendsLeaderboard = []; return }
        if blockedUserIds.isEmpty { await refreshBlockedUsers() }
        do {
            let friendships: [FriendshipRow] = try await client
                .from("friendships")
                .select()
                .eq("user_id_1", value: currentId.uuidString)
                .execute()
                .value
            let friendIds = friendships.map { $0.userId2.uuidString }
            guard !friendIds.isEmpty else { friendsLeaderboard = []; return }
            let profiles: [ProfileWithStats] = try await client
                .from("profiles")
                .select("*, user_stats(*)")
                .in("id", values: friendIds)
                .execute()
                .value
            friendsLeaderboard = profiles
                .map { $0.asSocialProfile() }
                .filter { !blockedUserIds.contains(UUID(uuidString: $0.id) ?? UUID()) }
                .sorted { $0.weeklyXP > $1.weeklyXP }
        } catch {
            friendsLeaderboard = []
        }
    }

    // MARK: - Relationship state

    func relationshipState(for profileId: UUID) async -> RelationshipState {
        guard let currentId = currentUserId else { return .none }
        if profileId == currentId { return .isSelf }
        do {
            let friendships: [FriendshipRow] = try await client
                .from("friendships")
                .select()
                .eq("user_id_1", value: currentId.uuidString)
                .eq("user_id_2", value: profileId.uuidString)
                .limit(1)
                .execute()
                .value
            if !friendships.isEmpty { return .friends }

            let sent: [FriendRequestRow] = try await client
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: currentId.uuidString)
                .eq("to_user_id", value: profileId.uuidString)
                .eq("status", value: "pending")
                .limit(1)
                .execute()
                .value
            if !sent.isEmpty { return .pendingSent }

            let received: [FriendRequestRow] = try await client
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: profileId.uuidString)
                .eq("to_user_id", value: currentId.uuidString)
                .eq("status", value: "pending")
                .limit(1)
                .execute()
                .value
            if !received.isEmpty { return .pendingReceived }

            return .none
        } catch {
            return .none
        }
    }

    // MARK: - Recent scores for a user

    func fetchRecentScores(for userId: UUID) async -> [Int] {
        do {
            let scores: [SessionScoreRow] = try await client
                .from("session_scores")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value
            return scores.map(\.score)
        } catch {
            return []
        }
    }

    // MARK: - Send friend request

    func sendFriendRequest(to userId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("friend_requests")
            .insert(NewFriendRequest(fromUserId: currentId, toUserId: userId, status: "pending"))
            .execute()
    }

    // MARK: - Accept/decline

    func acceptRequest(_ requestId: UUID, fromUserId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("friend_requests")
            .update(["status": "accepted"])
            .eq("id", value: requestId.uuidString)
            .execute()
        try await client
            .from("friendships")
            .insert([
                NewFriendship(userId1: currentId, userId2: fromUserId),
                NewFriendship(userId1: fromUserId, userId2: currentId)
            ])
            .execute()
        await refreshPendingRequestCount()
    }

    func declineRequest(_ requestId: UUID) async throws {
        try await client
            .from("friend_requests")
            .update(["status": "declined"])
            .eq("id", value: requestId.uuidString)
            .execute()
        await refreshPendingRequestCount()
    }

    func acceptRequestFrom(_ userId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        let requests: [FriendRequestRow] = try await client
            .from("friend_requests")
            .select()
            .eq("from_user_id", value: userId.uuidString)
            .eq("to_user_id", value: currentId.uuidString)
            .eq("status", value: "pending")
            .limit(1)
            .execute()
            .value
        guard let request = requests.first else { return }
        try await acceptRequest(request.id, fromUserId: userId)
    }

    // MARK: - Unfriend

    /// Atomically removes the friendship between the current user and `userId`,
    /// and wipes any historical `friend_requests` rows between them so a future
    /// re-friend isn't blocked by the unique (from_user_id, to_user_id) constraint.
    func removeFriend(_ userId: UUID) async throws {
        guard currentUserId != nil else { return }
        struct UnfriendParams: Encodable {
            let other_user_id: String
        }
        try await client
            .rpc("unfriend_user", params: UnfriendParams(other_user_id: userId.uuidString))
            .execute()
        await fetchFriendsLeaderboard()
    }

    // MARK: - Cancel sent request

    /// Deletes the current user's pending outgoing friend request to `userId`.
    /// Relies on the `friend_requests_delete_own_pending` RLS policy.
    func cancelFriendRequest(to userId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("friend_requests")
            .delete()
            .eq("from_user_id", value: currentId.uuidString)
            .eq("to_user_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
    }

    // MARK: - Pending request count (for badge)

    func refreshPendingRequestCount() async {
        guard let currentId = currentUserId else { pendingRequestCount = 0; return }
        do {
            let rows: [FriendRequestRow] = try await client
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: currentId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value
            pendingRequestCount = rows.count
        } catch {
            pendingRequestCount = 0
        }
    }

    // MARK: - Pending requests with sender profiles (for sheet)

    func fetchPendingRequestsWithProfiles() async -> [FriendRequestWithProfile] {
        guard let currentId = currentUserId else { return [] }
        do {
            let requests: [FriendRequestRow] = try await client
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: currentId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value
            guard !requests.isEmpty else { return [] }
            let senderIds = requests.map { $0.fromUserId.uuidString }
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .in("id", values: senderIds)
                .execute()
                .value
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            return requests.map { FriendRequestWithProfile(request: $0, senderProfile: profileMap[$0.fromUserId]) }
        } catch {
            return []
        }
    }

    // MARK: - Block / Unblock

    func refreshBlockedUsers() async {
        guard let currentId = currentUserId else { blockedUserIds = []; return }
        do {
            let rows: [BlockedUserRow] = try await client
                .from("blocked_users")
                .select()
                .eq("blocker_id", value: currentId.uuidString)
                .execute()
                .value
            blockedUserIds = Set(rows.compactMap { UUID(uuidString: $0.blockedId.uuidString) })
        } catch {
            blockedUserIds = []
        }
    }

    func blockUser(_ userId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("blocked_users")
            .insert(NewBlockedUser(blockerId: currentId, blockedId: userId))
            .execute()
        blockedUserIds.insert(userId)
        // Remove any existing friendship and pending requests in both directions
        _ = try? await client.from("friendships").delete()
            .or("user_id_1.eq.\(currentId.uuidString),user_id_2.eq.\(currentId.uuidString)")
            .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
            .execute()
        _ = try? await client.from("friend_requests").delete()
            .or("from_user_id.eq.\(userId.uuidString),to_user_id.eq.\(userId.uuidString)")
            .execute()
        await fetchFriendsLeaderboard()
    }

    func unblockUser(_ userId: UUID) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: currentId.uuidString)
            .eq("blocked_id", value: userId.uuidString)
            .execute()
        blockedUserIds.remove(userId)
    }

    // MARK: - Report

    func reportUser(_ userId: UUID, reason: String, details: String?) async throws {
        guard let currentId = currentUserId else { return }
        try await client
            .from("user_reports")
            .insert(NewUserReport(reporterId: currentId, reportedId: userId, reason: reason, details: details))
            .execute()
    }

    // MARK: - Personal Bests

    func fetchPersonalBest(mode: SessionMode) async -> Int? {
        guard let currentId = currentUserId else { return nil }
        do {
            let rows: [PersonalBestRow] = try await client
                .from("personal_bests")
                .select()
                .eq("user_id", value: currentId.uuidString)
                .eq("mode", value: mode.rawValue)
                .limit(1)
                .execute()
                .value
            return rows.first?.bestScore
        } catch {
            return nil
        }
    }

    func recordPersonalBest(mode: SessionMode, score: Int) async {
        guard let currentId = currentUserId else { return }
        do {
            try await client
                .from("personal_bests")
                .upsert(PersonalBestUpsert(
                    userId: currentId,
                    mode: mode.rawValue,
                    bestScore: score,
                    achievedAt: .now
                ), onConflict: "user_id,mode")
                .execute()
        } catch {
            // Non-fatal — PB tracking is best-effort.
        }
    }
}
