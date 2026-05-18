import Foundation

enum GamificationService {

    static func awardXP(
        to user: User,
        wasDailyChallenge: Bool,
        score: Int,
        difficultyLevel: Int,
        previousBest: Int?,
        currentStreak: Int
    ) {
        user.xp += xpForSession(
            wasDailyChallenge: wasDailyChallenge,
            score: score,
            difficultyLevel: difficultyLevel,
            previousBest: previousBest,
            currentStreak: currentStreak
        )
    }

    static func updateStreak(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let lastDate = user.lastSessionDate else {
            user.currentStreak = 1
            user.longestStreak = max(user.longestStreak, 1)
            user.lastSessionDate = .now
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

    static func xpForSession(
        wasDailyChallenge: Bool,
        score: Int,
        difficultyLevel: Int,
        previousBest: Int?,
        currentStreak: Int
    ) -> Int {
        let raw =
            AppConstants.baseXP
            + scoreBonus(for: score)
            + difficultyBonus(for: difficultyLevel)
            + (wasDailyChallenge ? AppConstants.dailyChallengeXP : 0)
            + personalBestBonus(score: score, previousBest: previousBest)
        let total = Double(raw) * streakMultiplier(streak: currentStreak)
        return Int(total.rounded())
    }

    static func scoreBonus(for score: Int) -> Int {
        let clamped = min(max(score, 0), 100)
        return max(0, clamped - 50)
    }

    static func difficultyBonus(for level: Int) -> Int {
        guard level >= 6 else { return 0 }
        let multiplier = min((level - 4) / 2, 3)
        return multiplier * AppConstants.difficultyXPBonus
    }

    static func streakMultiplier(streak: Int) -> Double {
        let cappedStreak = min(max(streak, 0), 10)
        return 1.0 + Double(cappedStreak) * 0.05
    }

    static func personalBestBonus(score: Int, previousBest: Int?) -> Int {
        guard let previousBest else { return 0 }
        return score > previousBest ? AppConstants.personalBestXPBonus : 0
    }
}
