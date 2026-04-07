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

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(goal))
    }

    init(id: String, name: String, descriptionText: String, iconName: String, goal: Int) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.iconName = iconName
        self.isUnlocked = false
        self.unlockedDate = nil
        self.progress = 0
        self.goal = goal
    }

    static let definitions: [(id: String, name: String, description: String, icon: String, goal: Int)] = [
        ("first_session", "First Session", "Complete your first session", "mic.fill", 1),
        ("streak_7", "7-Day Streak", "Practice 7 days in a row", "flame.fill", 7),
        ("interview_pro", "Interview Pro", "Complete 10 interview sessions", "briefcase.fill", 10),
        ("score_80", "Score 80+", "Achieve an overall score of 80 or higher", "star.fill", 1),
        ("zero_fillers", "Zero Fillers", "Complete a session with 0 filler words", "checkmark.seal.fill", 1),
        ("rank_5", "Rank 5", "Reach Rank 5 (Rhetorician)", "trophy.fill", 1),
        ("sessions_30", "30 Sessions", "Complete 30 total sessions", "repeat", 30),
        ("master", "Master", "Reach Rank 10", "crown.fill", 1)
    ]
}
