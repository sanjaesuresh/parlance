import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: String
    var name: String
    var descriptionText: String
    var iconName: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Int
    var goal: Int

    /// 1 = Bronze, 2 = Silver, 3 = Gold. Defaulted for migration of pre-existing rows.
    var tier: Int = 1

    /// One of: "score", "streak", "consistency", "volume", "variety", "mastery".
    /// Drives sort + grouping on the badge row.
    var category: String = "mastery"

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(goal))
    }

    var emoji: String {
        switch iconName {
        case "mic.fill": return "\u{1F3A4}"
        case "flame.fill": return "\u{1F525}"
        case "briefcase.fill": return "\u{1F4BC}"
        case "star.fill": return "\u{2B50}"
        case "star.circle.fill": return "\u{1F31F}"
        case "sparkles": return "\u{2728}"
        case "checkmark.seal.fill": return "\u{2705}"
        case "trophy.fill": return "\u{1F3C6}"
        case "repeat": return "\u{1F501}"
        case "crown.fill": return "\u{1F451}"
        case "globe": return "\u{1F30D}"
        case "clock.badge.checkmark": return "\u{23F1}\u{FE0F}"
        case "clock": return "\u{23F0}"
        case "chart.line.uptrend.xyaxis": return "\u{1F4C8}"
        case "medal.fill": return "\u{1F396}\u{FE0F}"
        default: return "\u{1F3AF}"
        }
    }

    init(
        id: String,
        name: String,
        descriptionText: String,
        iconName: String,
        goal: Int,
        tier: Int = 1,
        category: String = "mastery"
    ) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.iconName = iconName
        self.isUnlocked = false
        self.unlockedDate = nil
        self.progress = 0
        self.goal = goal
        self.tier = tier
        self.category = category
    }

    // MARK: - Catalog
    //
    // Tier 1 = Bronze (entry-level, achievable in the first week)
    // Tier 2 = Silver (sustained practice, mid-game)
    // Tier 3 = Gold (mastery, hard to earn — the prestige badges)
    //
    // Categories drive the badge-row sort order:
    //   score → streak → consistency → volume → variety → mastery

    struct Definition {
        let id: String
        let name: String
        let description: String
        let icon: String
        let goal: Int
        let tier: Int
        let category: String
    }

    static let definitions: [Definition] = [
        // --- Bronze ---
        .init(id: "first_session", name: "First Session",
              description: "Complete your first session.",
              icon: "mic.fill", goal: 1, tier: 1, category: "volume"),
        .init(id: "score_80", name: "Score 80",
              description: "Hit 80 or higher on a single session.",
              icon: "star.fill", goal: 1, tier: 1, category: "score"),
        .init(id: "streak_3", name: "3-Day Streak",
              description: "Practice 3 days in a row.",
              icon: "flame.fill", goal: 3, tier: 1, category: "streak"),
        .init(id: "tour_modes", name: "Tourist",
              description: "Try all four free modes (Interview, Daily Convo, Impromptu, Explain a Topic).",
              icon: "globe", goal: 4, tier: 1, category: "variety"),
        .init(id: "zero_fillers", name: "Zero Fillers",
              description: "Complete a session with zero filler words.",
              icon: "checkmark.seal.fill", goal: 1, tier: 1, category: "mastery"),

        // --- Silver ---
        .init(id: "score_90", name: "Score 90",
              description: "Hit 90 or higher on a single session.",
              icon: "sparkles", goal: 1, tier: 2, category: "score"),
        .init(id: "streak_7", name: "Week Warrior",
              description: "Practice 7 days in a row.",
              icon: "flame.fill", goal: 7, tier: 2, category: "streak"),
        .init(id: "sessions_30", name: "30 Sessions",
              description: "Complete 30 sessions total.",
              icon: "repeat", goal: 30, tier: 2, category: "volume"),
        .init(id: "spoke_10h", name: "10 Hours",
              description: "Spend 10 hours practicing (cumulative).",
              icon: "clock", goal: 36_000, tier: 2, category: "volume"),
        .init(id: "avg_80", name: "Steady 80",
              description: "Lifetime average score ≥ 80 (10+ sessions required).",
              icon: "chart.line.uptrend.xyaxis", goal: 1, tier: 2, category: "consistency"),
        .init(id: "interview_pro", name: "Interview Pro",
              description: "Complete 10 Job Interview sessions.",
              icon: "briefcase.fill", goal: 10, tier: 2, category: "variety"),
        .init(id: "rank_5", name: "Rhetorician",
              description: "Reach Rank 5.",
              icon: "trophy.fill", goal: 1, tier: 2, category: "mastery"),

        // --- Gold ---
        .init(id: "score_100", name: "Perfect Run",
              description: "Hit a perfect 100 on a session.",
              icon: "star.circle.fill", goal: 1, tier: 3, category: "score"),
        .init(id: "streak_30", name: "Month Strong",
              description: "Practice 30 days in a row.",
              icon: "medal.fill", goal: 30, tier: 3, category: "streak"),
        .init(id: "streak_100", name: "Centurion",
              description: "Practice 100 days in a row.",
              icon: "flame.fill", goal: 100, tier: 3, category: "streak"),
        .init(id: "avg_90", name: "Elite",
              description: "Lifetime average score ≥ 90 (10+ sessions required).",
              icon: "star.circle.fill", goal: 1, tier: 3, category: "consistency"),
        .init(id: "master", name: "Master Orator",
              description: "Reach Rank 10.",
              icon: "crown.fill", goal: 1, tier: 3, category: "mastery"),
    ]

    static let categoryOrder: [String: Int] = [
        "score": 0,
        "streak": 1,
        "consistency": 2,
        "volume": 3,
        "variety": 4,
        "mastery": 5,
    ]
}
