import Testing
@testable import Parlance

@Suite("GamificationService.streakMultiplier")
struct StreakMultiplierTests {

    @Test("returns 1.0 when streak is zero")
    func zeroStreak() {
        #expect(GamificationService.streakMultiplier(streak: 0) == 1.0)
    }

    @Test("returns 1.05 on day 1")
    func dayOne() {
        #expect(GamificationService.streakMultiplier(streak: 1) == 1.05)
    }

    @Test("returns 1.50 on day 10")
    func dayTen() {
        #expect(GamificationService.streakMultiplier(streak: 10) == 1.50)
    }

    @Test("caps at 1.50 for streaks above 10")
    func above10() {
        #expect(GamificationService.streakMultiplier(streak: 30) == 1.50)
    }
}

@Suite("GamificationService.scoreBonus")
struct ScoreBonusTests {

    @Test("zero at or below 50")
    func zeroBelow50() {
        #expect(GamificationService.scoreBonus(for: 0) == 0)
        #expect(GamificationService.scoreBonus(for: 50) == 0)
    }

    @Test("+1 per point above 50")
    func linearAbove50() {
        #expect(GamificationService.scoreBonus(for: 51) == 1)
        #expect(GamificationService.scoreBonus(for: 75) == 25)
        #expect(GamificationService.scoreBonus(for: 95) == 45)
    }

    @Test("caps at +50 at score 100")
    func capsAt100() {
        #expect(GamificationService.scoreBonus(for: 100) == 50)
    }

    @Test("does not exceed +50 for invalid >100 scores")
    func clampsAbove100() {
        #expect(GamificationService.scoreBonus(for: 120) == 50)
    }
}

@Suite("GamificationService.personalBestBonus")
struct PersonalBestBonusTests {

    @Test("first-ever session in a mode does not award PB bonus")
    func firstEver() {
        #expect(GamificationService.personalBestBonus(score: 85, previousBest: nil) == 0)
    }

    @Test("beating previous best awards +100")
    func newBest() {
        #expect(GamificationService.personalBestBonus(score: 90, previousBest: 80) == 100)
    }

    @Test("equalling previous best does not award")
    func tie() {
        #expect(GamificationService.personalBestBonus(score: 80, previousBest: 80) == 0)
    }

    @Test("scoring below previous best does not award")
    func below() {
        #expect(GamificationService.personalBestBonus(score: 70, previousBest: 80) == 0)
    }
}

@Suite("GamificationService.xpForSession")
struct XPForSessionTests {

    @Test("baseline session — score 60, no daily, level 1, no streak, no PB")
    func baseline() {
        // base 120 + score 10 + diff 0 + daily 0 + pb 0 = 130, streak 1.0
        let xp = GamificationService.xpForSession(
            wasDailyChallenge: false,
            score: 60,
            difficultyLevel: 1,
            previousBest: 60,
            currentStreak: 0
        )
        #expect(xp == 130)
    }

    @Test("worked spec example — 95 at L8, streak day 5, no daily, no PB")
    func specExample() {
        // (120 + 45 + 40 + 0 + 0) * 1.25 = 256.25 → 256
        let xp = GamificationService.xpForSession(
            wasDailyChallenge: false,
            score: 95,
            difficultyLevel: 8,
            previousBest: 95,    // not exceeded — no PB
            currentStreak: 5
        )
        #expect(xp == 256)
    }

    @Test("daily challenge stacks")
    func dailyStacks() {
        // (120 + 30 + 0 + 200 + 0) * 1.0 = 350
        let xp = GamificationService.xpForSession(
            wasDailyChallenge: true,
            score: 80,
            difficultyLevel: 5,
            previousBest: 80,
            currentStreak: 0
        )
        #expect(xp == 350)
    }

    @Test("personal best stacks")
    func pbStacks() {
        // base 120 + score 40 + diff 0 + daily 0 + pb 100 = 260, streak 1.0
        let xp = GamificationService.xpForSession(
            wasDailyChallenge: false,
            score: 90,
            difficultyLevel: 1,
            previousBest: 85,
            currentStreak: 0
        )
        #expect(xp == 260)
    }
}
