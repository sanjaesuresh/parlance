import Foundation

struct SocialProfile: Identifiable {
    let id: String
    let displayName: String
    let username: String
    let avatarEmoji: String
    let location: String?
    let occupation: String?
    let xp: Int
    let weeklyXP: Int
    let currentStreak: Int
    let avgScore: Int
    let totalSessions: Int
    let rankLevel: Int
    let recentScores: [Int]

    var rank: Rank { Rank.from(xp: xp) }
}
