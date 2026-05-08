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

    private let client = SupabaseManager.shared.client

    var currentUserId: UUID? { client.auth.currentUser?.id }

    // MARK: - User search

    func searchUsers(query: String) async -> [SocialProfile] {
        let safe = query.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            .trimmingCharacters(in: .whitespaces)
        guard !safe.isEmpty, let currentId = currentUserId else { return [] }
        do {
            let profiles: [ProfileWithStats] = try await client
                .from("profiles")
                .select("*, user_stats(*)")
                .or("username.ilike.%\(safe)%,display_name.ilike.%\(safe)%")
                .neq("id", value: currentId.uuidString)
                .limit(20)
                .execute()
                .value
            return profiles.map { $0.asSocialProfile() }
        } catch {
            return []
        }
    }

    // MARK: - Leaderboard

    func fetchFriendsLeaderboard() async {
        guard let currentId = currentUserId else { friendsLeaderboard = []; return }
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
}
