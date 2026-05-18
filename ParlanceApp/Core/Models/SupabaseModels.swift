// Parlance/Core/Models/SupabaseModels.swift
import Foundation
import Supabase

// MARK: - ProfileRow

struct ProfileRow: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let location: String?
    let occupation: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarEmoji = "avatar_emoji"
        case avatarUrl = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case location
        case occupation
        case createdAt = "created_at"
    }
}

// MARK: - UserStatsRow

struct UserStatsRow: Codable {
    let userId: UUID
    var xp: Int
    var weeklyXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var avgScore: Int
    var totalSessions: Int
    var lastSessionAt: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case xp
        case weeklyXP = "weekly_xp"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case avgScore = "avg_score"
        case totalSessions = "total_sessions"
        case lastSessionAt = "last_session_at"
        case updatedAt = "updated_at"
    }

    init(userId: UUID, xp: Int, weeklyXP: Int, currentStreak: Int, longestStreak: Int,
         avgScore: Int, totalSessions: Int, lastSessionAt: Date?) {
        self.userId = userId
        self.xp = xp
        self.weeklyXP = weeklyXP
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.avgScore = avgScore
        self.totalSessions = totalSessions
        self.lastSessionAt = lastSessionAt
        self.updatedAt = Date()
    }
}

// MARK: - SessionScoreRow

struct SessionScoreRow: Codable {
    let id: UUID
    let userId: UUID
    let clientSessionId: UUID
    let score: Int
    let mode: String
    let level: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case clientSessionId = "client_session_id"
        case score
        case mode
        case level
        case createdAt = "created_at"
    }

    init(userId: UUID, clientSessionId: UUID, score: Int, mode: String, level: Int) {
        self.id = UUID()
        self.userId = userId
        self.clientSessionId = clientSessionId
        self.score = score
        self.mode = mode
        self.level = level
        self.createdAt = Date()
    }
}

// MARK: - FriendRequestRow

struct FriendRequestRow: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - FriendshipRow

struct FriendshipRow: Codable {
    let userId1: UUID
    let userId2: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId1 = "user_id_1"
        case userId2 = "user_id_2"
        case createdAt = "created_at"
    }
}

// MARK: - ProfileWithStats (joined select result)

struct ProfileWithStats: Codable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let location: String?
    let occupation: String?
    let userStats: UserStatsRow?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarEmoji = "avatar_emoji"
        case avatarUrl = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case location
        case occupation
        case userStats = "user_stats"
    }

    func asSocialProfile(recentScores: [Int] = []) -> SocialProfile {
        let stats = userStats
        return SocialProfile(
            id: id.uuidString,
            displayName: displayName,
            username: username,
            avatarEmoji: avatarEmoji,
            avatarUrl: avatarUrl,
            avatarUpdatedAt: avatarUpdatedAt,
            location: location,
            occupation: occupation,
            xp: stats?.xp ?? 0,
            weeklyXP: stats?.weeklyXP ?? 0,
            currentStreak: stats?.currentStreak ?? 0,
            avgScore: stats?.avgScore ?? 0,
            totalSessions: stats?.totalSessions ?? 0,
            rankLevel: Rank.from(xp: stats?.xp ?? 0).level,
            recentScores: recentScores
        )
    }
}

// MARK: - FriendRequestWithProfile

struct FriendRequestWithProfile: Identifiable {
    let request: FriendRequestRow
    let senderProfile: ProfileRow?

    var id: UUID { request.id }
}

// MARK: - Insert helpers

struct NewFriendRequest: Encodable {
    let fromUserId: UUID
    let toUserId: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
    }
}

struct NewFriendship: Encodable {
    let userId1: UUID
    let userId2: UUID

    enum CodingKeys: String, CodingKey {
        case userId1 = "user_id_1"
        case userId2 = "user_id_2"
    }
}

// MARK: - Blocked users

struct BlockedUserRow: Decodable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct NewBlockedUser: Encodable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

// MARK: - User reports

struct NewUserReport: Encodable {
    let reporterId: UUID
    let reportedId: UUID
    let reason: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case reportedId = "reported_id"
        case reason
        case details
    }
}

struct NewProfile: Encodable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarEmoji: String
    let location: String?
    let occupation: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarEmoji = "avatar_emoji"
        case location
        case occupation
    }
}

// MARK: - PersonalBest

struct PersonalBestRow: Codable {
    let userId: UUID
    let mode: String
    let bestScore: Int
    let achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case mode
        case bestScore = "best_score"
        case achievedAt = "achieved_at"
    }
}

struct PersonalBestUpsert: Encodable {
    let userId: UUID
    let mode: String
    let bestScore: Int
    let achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case mode
        case bestScore = "best_score"
        case achievedAt = "achieved_at"
    }
}

// MARK: - Friend Activity

struct FriendActivityRow: Codable {
    let actorId: UUID
    let actorUsername: String
    let actorDisplayName: String
    let actorAvatarEmoji: String
    let actorAvatarUrl: String?
    let actorAvatarUpdatedAt: Date?
    let eventType: String
    let eventAt: Date
    let payload: AnyJSON

    enum CodingKeys: String, CodingKey {
        case actorId = "actor_id"
        case actorUsername = "actor_username"
        case actorDisplayName = "actor_display_name"
        case actorAvatarEmoji = "actor_avatar_emoji"
        case actorAvatarUrl = "actor_avatar_url"
        case actorAvatarUpdatedAt = "actor_avatar_updated_at"
        case eventType = "event_type"
        case eventAt = "event_at"
        case payload
    }

    func toEvent() -> ActivityEvent? {
        // Pull mode and score from the payload JSON.
        guard case .object(let payloadObject) = payload else { return nil }

        let modeString: String? = {
            if case .string(let s) = payloadObject["mode"] { return s }
            return nil
        }()
        let scoreInt: Int? = {
            if case .integer(let i) = payloadObject["score"] { return i }
            if case .double(let d) = payloadObject["score"] { return Int(d) }
            return nil
        }()

        let mode = modeString.flatMap(SessionMode.init(rawValue:)) ?? .casual
        let score = scoreInt ?? 0

        let kind: ActivityEventKind
        switch eventType {
        case "score": kind = .score(value: score, mode: mode)
        case "personal_best": kind = .personalBest(mode: mode, score: score)
        default: return nil
        }
        return ActivityEvent(
            actorUsername: actorUsername,
            actorDisplayName: actorDisplayName,
            actorAvatarEmoji: actorAvatarEmoji,
            occurredAt: eventAt,
            kind: kind,
            actorAvatarUrl: actorAvatarUrl,
            actorAvatarUpdatedAt: actorAvatarUpdatedAt
        )
    }
}

// MARK: - GlobalLeaderboard

struct GlobalLeaderboardRow: Codable {
    let id: UUID
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let weeklyXP: Int
    let rank: Int
    let tier: String

    enum CodingKeys: String, CodingKey {
        case id, username, rank, tier
        case avatarEmoji = "avatar_emoji"
        case avatarUrl = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case weeklyXP = "weekly_xp"
    }

    func asEntry() -> GlobalLeaderboardEntry {
        GlobalLeaderboardEntry(
            id: id.uuidString,
            username: username,
            avatarEmoji: avatarEmoji,
            avatarUrl: avatarUrl,
            avatarUpdatedAt: avatarUpdatedAt,
            weeklyXP: weeklyXP,
            rank: rank,
            tier: LeagueTier(rawValue: tier) ?? .bronze
        )
    }
}

struct GlobalLeaderboardResponse: Codable {
    let top: [GlobalLeaderboardRow]
    let me: GlobalLeaderboardRow?
}

// MARK: - PublicProfile RPC row

struct PublicProfileRow: Codable {
    let id: UUID
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let weeklyXP: Int
    let tier: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarEmoji = "avatar_emoji"
        case avatarUrl = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case weeklyXP = "weekly_xp"
        case tier
    }

    func asPublicProfile() -> PublicProfile {
        PublicProfile(
            id: id.uuidString,
            username: username,
            avatarEmoji: avatarEmoji,
            avatarUrl: avatarUrl,
            avatarUpdatedAt: avatarUpdatedAt,
            weeklyXP: weeklyXP,
            tier: LeagueTier(rawValue: tier) ?? .bronze
        )
    }
}
