// Parlance/Core/Models/SupabaseModels.swift
import Foundation

// MARK: - ProfileRow

struct ProfileRow: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarEmoji: String
    let location: String?
    let occupation: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarEmoji = "avatar_emoji"
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
    let score: Int
    let mode: String
    let level: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case score
        case mode
        case level
        case createdAt = "created_at"
    }

    init(userId: UUID, score: Int, mode: String, level: Int) {
        self.id = UUID()
        self.userId = userId
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
    let location: String?
    let occupation: String?
    let userStats: UserStatsRow?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarEmoji = "avatar_emoji"
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

// MARK: - PublicProfile RPC row

struct PublicProfileRow: Codable {
    let id: UUID
    let username: String
    let avatarEmoji: String
    let weeklyXP: Int
    let tier: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarEmoji = "avatar_emoji"
        case weeklyXP = "weekly_xp"
        case tier
    }

    func asPublicProfile() -> PublicProfile {
        PublicProfile(
            id: id.uuidString,
            username: username,
            avatarEmoji: avatarEmoji,
            weeklyXP: weeklyXP,
            tier: LeagueTier(rawValue: tier) ?? .bronze
        )
    }
}
