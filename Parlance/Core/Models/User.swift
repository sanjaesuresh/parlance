import Foundation
import SwiftData

@Model
final class User {
    var displayName: String
    var username: String?
    var location: String?
    var occupation: String?
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
    var dailyChallengeCompletedDate: Date?

    init(
        displayName: String,
        username: String? = nil,
        location: String? = nil,
        occupation: String? = nil,
        avatarEmoji: String,
        joinDate: Date = .now,
        xp: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastSessionDate: Date? = nil,
        practiceLevel: Int = 5,
        hasCompletedSetup: Bool = false,
        dailySessionCount: Int = 0,
        lastDailySessionDate: Date? = nil,
        dailyChallengeLevelLock: Int? = nil,
        dailyChallengeLockDate: Date? = nil,
        dailyChallengeCompletedDate: Date? = nil
    ) {
        self.displayName = displayName
        self.username = username
        self.location = location
        self.occupation = occupation
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
        self.dailyChallengeCompletedDate = dailyChallengeCompletedDate
    }

    var rank: Rank { Rank.from(xp: xp) }

    var hasDailyChallengeCompletedToday: Bool {
        guard let date = dailyChallengeCompletedDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

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
