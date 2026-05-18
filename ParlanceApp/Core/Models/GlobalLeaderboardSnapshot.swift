import Foundation

struct GlobalLeaderboardEntry: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarEmoji: String
    let weeklyXP: Int
    let rank: Int
    let tier: LeagueTier
}

struct GlobalLeaderboardSnapshot {
    let top: [GlobalLeaderboardEntry]
    let me: GlobalLeaderboardEntry?
}
