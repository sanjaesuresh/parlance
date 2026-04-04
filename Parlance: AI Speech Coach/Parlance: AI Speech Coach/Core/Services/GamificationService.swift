import Foundation

enum GamificationService {

    static func awardXP(to user: User, wasDailyChallenge: Bool) {
        user.xp += AppConstants.baseXP
        if wasDailyChallenge {
            user.xp += AppConstants.dailyChallengeXP
        }
    }

    static func updateStreak(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let lastDate = user.lastSessionDate else {
            user.currentStreak = 1
            user.longestStreak = max(user.longestStreak, 1)
            return
        }

        let lastDay = calendar.startOfDay(for: lastDate)

        if lastDay == today {
            return
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if lastDay == calendar.startOfDay(for: yesterday) {
            user.currentStreak += 1
        } else {
            user.currentStreak = 1
        }

        user.longestStreak = max(user.longestStreak, user.currentStreak)
        user.lastSessionDate = .now
    }

    static func incrementDailySessionCount(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lastDate = user.lastDailySessionDate,
           calendar.startOfDay(for: lastDate) == today {
            user.dailySessionCount += 1
        } else {
            user.dailySessionCount = 1
            user.lastDailySessionDate = .now
        }
    }

    static func headlineVerdict(for score: Int) -> String {
        switch score {
        case 80...100: "Strong performance."
        case 60..<80: "Getting there."
        default: "Room to grow."
        }
    }

    static func xpForSession(wasDailyChallenge: Bool) -> Int {
        AppConstants.baseXP + (wasDailyChallenge ? AppConstants.dailyChallengeXP : 0)
    }
}
