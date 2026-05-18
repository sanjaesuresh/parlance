import Foundation

struct PublicProfile: Identifiable {
    let id: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let weeklyXP: Int
    let tier: LeagueTier

    init(
        id: String,
        username: String,
        avatarEmoji: String,
        avatarUrl: String? = nil,
        avatarUpdatedAt: Date? = nil,
        weeklyXP: Int,
        tier: LeagueTier
    ) {
        self.id = id
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.avatarUrl = avatarUrl
        self.avatarUpdatedAt = avatarUpdatedAt
        self.weeklyXP = weeklyXP
        self.tier = tier
    }
}
