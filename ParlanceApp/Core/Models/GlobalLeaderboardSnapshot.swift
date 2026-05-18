import Foundation

struct GlobalLeaderboardEntry: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let weeklyXP: Int
    let rank: Int
    let tier: LeagueTier

    init(
        id: String,
        username: String,
        avatarEmoji: String,
        avatarUrl: String? = nil,
        avatarUpdatedAt: Date? = nil,
        weeklyXP: Int,
        rank: Int,
        tier: LeagueTier
    ) {
        self.id = id
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.avatarUrl = avatarUrl
        self.avatarUpdatedAt = avatarUpdatedAt
        self.weeklyXP = weeklyXP
        self.rank = rank
        self.tier = tier
    }
}

struct GlobalLeaderboardSnapshot {
    let top: [GlobalLeaderboardEntry]
    let me: GlobalLeaderboardEntry?
}
