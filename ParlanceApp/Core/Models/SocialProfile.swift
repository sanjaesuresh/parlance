import Foundation

struct SocialProfile: Identifiable {
    let id: String
    let displayName: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let location: String?
    let occupation: String?
    let xp: Int
    let weeklyXP: Int
    let currentStreak: Int
    let avgScore: Int
    let totalSessions: Int
    let rankLevel: Int
    let recentScores: [Int]

    init(
        id: String,
        displayName: String,
        username: String,
        avatarEmoji: String,
        avatarUrl: String? = nil,
        avatarUpdatedAt: Date? = nil,
        location: String? = nil,
        occupation: String? = nil,
        xp: Int,
        weeklyXP: Int,
        currentStreak: Int,
        avgScore: Int,
        totalSessions: Int,
        rankLevel: Int,
        recentScores: [Int]
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.avatarUrl = avatarUrl
        self.avatarUpdatedAt = avatarUpdatedAt
        self.location = location
        self.occupation = occupation
        self.xp = xp
        self.weeklyXP = weeklyXP
        self.currentStreak = currentStreak
        self.avgScore = avgScore
        self.totalSessions = totalSessions
        self.rankLevel = rankLevel
        self.recentScores = recentScores
    }

    var rank: Rank { Rank.from(xp: xp) }
}
