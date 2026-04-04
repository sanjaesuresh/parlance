import Foundation
import SwiftData

@Model
final class User {
    var displayName: String
    var avatarEmoji: String
    var joinDate: Date
    var xp: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: Date?
    var practiceLevel: Int
    var hasCompletedSetup: Bool
    var dailySessionCount: Int
    var lastDailySessionDate: Date?
    var dailyChallengeLevelLock: Int?
    var dailyChallengeLockDate: Date?

    init(
        displayName: String,
        avatarEmoji: String,
        joinDate: Date = .now,
        xp: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastSessionDate: Date? = nil,
        practiceLevel: Int = 1,
        hasCompletedSetup: Bool = false,
        dailySessionCount: Int = 0,
        lastDailySessionDate: Date? = nil,
        dailyChallengeLevelLock: Int? = nil,
        dailyChallengeLockDate: Date? = nil
    ) {
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.joinDate = joinDate
        self.xp = xp
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastSessionDate = lastSessionDate
        self.practiceLevel = practiceLevel
        self.hasCompletedSetup = hasCompletedSetup
        self.dailySessionCount = dailySessionCount
        self.lastDailySessionDate = lastDailySessionDate
        self.dailyChallengeLevelLock = dailyChallengeLevelLock
        self.dailyChallengeLockDate = dailyChallengeLockDate
    }

    var rank: Rank { Rank.from(xp: xp) }

    var isAtDailyLimit: Bool { dailySessionCount >= AppConstants.maxSessionsPerDay }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
