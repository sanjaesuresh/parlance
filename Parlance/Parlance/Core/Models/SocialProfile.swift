import Foundation

/// Represents another user's public profile for leaderboard and social features.
/// In MVP this uses mock data; will connect to a backend later.
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
    let recentScores: [Int] // last 5 session scores

    var rank: Rank { Rank.from(xp: xp) }

    // MARK: - Mock Data

    static let mockUsers: [SocialProfile] = [
        SocialProfile(
            id: "u_01", displayName: "Priya K.", username: "priya_speaks",
            avatarEmoji: "\u{1F680}", location: "San Francisco, CA", occupation: "Product Manager",
            xp: 4200, weeklyXP: 680, currentStreak: 12, avgScore: 74, totalSessions: 38,
            rankLevel: 5, recentScores: [78, 72, 81, 69, 75]
        ),
        SocialProfile(
            id: "u_02", displayName: "Marcus J.", username: "marcusj",
            avatarEmoji: "\u{1F525}", location: "Austin, TX", occupation: "Sales Lead",
            xp: 5800, weeklyXP: 540, currentStreak: 8, avgScore: 79, totalSessions: 52,
            rankLevel: 6, recentScores: [82, 76, 84, 77, 80]
        ),
        SocialProfile(
            id: "u_03", displayName: "Aisha M.", username: "aisha_orator",
            avatarEmoji: "\u{2B50}", location: "London, UK", occupation: "Startup Founder",
            xp: 7100, weeklyXP: 920, currentStreak: 21, avgScore: 83, totalSessions: 64,
            rankLevel: 7, recentScores: [88, 81, 85, 79, 86]
        ),
        SocialProfile(
            id: "u_04", displayName: "David L.", username: "david_talks",
            avatarEmoji: "\u{1F3A4}", location: "Toronto, Canada", occupation: "Software Engineer",
            xp: 2100, weeklyXP: 360, currentStreak: 4, avgScore: 67, totalSessions: 19,
            rankLevel: 3, recentScores: [62, 71, 68, 65, 70]
        ),
        SocialProfile(
            id: "u_05", displayName: "Sofia R.", username: "sofia_pitch",
            avatarEmoji: "\u{1F4BC}", location: "Miami, FL", occupation: "Marketing Director",
            xp: 3400, weeklyXP: 480, currentStreak: 6, avgScore: 71, totalSessions: 30,
            rankLevel: 4, recentScores: [73, 68, 75, 70, 72]
        ),
        SocialProfile(
            id: "u_06", displayName: "Tyler W.", username: "tyler_w",
            avatarEmoji: "\u{26A1}", location: "Seattle, WA", occupation: "Data Scientist",
            xp: 1500, weeklyXP: 240, currentStreak: 3, avgScore: 63, totalSessions: 14,
            rankLevel: 2, recentScores: [58, 65, 61, 67, 64]
        ),
        SocialProfile(
            id: "u_07", displayName: "Emma C.", username: "emma_coach",
            avatarEmoji: "\u{1F9E0}", location: "New York, NY", occupation: "Executive Coach",
            xp: 9200, weeklyXP: 1100, currentStreak: 30, avgScore: 87, totalSessions: 82,
            rankLevel: 8, recentScores: [89, 85, 91, 86, 88]
        ),
        SocialProfile(
            id: "u_08", displayName: "Kai N.", username: "kai_debate",
            avatarEmoji: "\u{1F5E3}", location: "Chicago, IL", occupation: "Law Student",
            xp: 6300, weeklyXP: 720, currentStreak: 15, avgScore: 80, totalSessions: 55,
            rankLevel: 6, recentScores: [83, 78, 82, 77, 81]
        ),
        SocialProfile(
            id: "u_09", displayName: "Lena H.", username: "lena_h",
            avatarEmoji: "\u{1F31F}", location: "Berlin, Germany", occupation: "UX Researcher",
            xp: 2800, weeklyXP: 300, currentStreak: 5, avgScore: 69, totalSessions: 24,
            rankLevel: 3, recentScores: [66, 72, 68, 71, 69]
        ),
        SocialProfile(
            id: "u_10", displayName: "Ravi P.", username: "ravi_speaks",
            avatarEmoji: "\u{1F3C6}", location: "Mumbai, India", occupation: "Consultant",
            xp: 4800, weeklyXP: 600, currentStreak: 9, avgScore: 76, totalSessions: 42,
            rankLevel: 5, recentScores: [79, 74, 78, 73, 77]
        ),
        SocialProfile(
            id: "u_11", displayName: "Zoe T.", username: "zoe_t",
            avatarEmoji: "\u{1F4D6}", location: "Sydney, Australia", occupation: "Teacher",
            xp: 3800, weeklyXP: 420, currentStreak: 7, avgScore: 72, totalSessions: 33,
            rankLevel: 4, recentScores: [74, 70, 73, 71, 75]
        ),
        SocialProfile(
            id: "u_12", displayName: "Jordan B.", username: "jordan_b",
            avatarEmoji: "\u{1F91D}", location: "Denver, CO", occupation: "Account Executive",
            xp: 1200, weeklyXP: 180, currentStreak: 2, avgScore: 60, totalSessions: 11,
            rankLevel: 2, recentScores: [55, 62, 58, 64, 61]
        )
    ]

    /// Search mock users by username prefix
    static func search(query: String) -> [SocialProfile] {
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        return mockUsers.filter {
            $0.username.lowercased().contains(lower) ||
            $0.displayName.lowercased().contains(lower)
        }
    }

    /// Leaderboard sorted by weekly XP
    static var weeklyLeaderboard: [SocialProfile] {
        mockUsers.sorted { $0.weeklyXP > $1.weeklyXP }
    }
}
