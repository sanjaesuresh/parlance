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
