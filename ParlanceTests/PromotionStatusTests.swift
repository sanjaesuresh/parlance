import Testing
import Foundation
@testable import Parlance

@Suite("LeagueViewModel.promotionStatus")
struct PromotionStatusTests {

    private func compute(
        weeklyXP: Int,
        tier: LeagueTier,
        hoursToReset: Int
    ) -> PromotionStatus {
        LeagueViewModel.promotionStatus(
            weeklyXP: weeklyXP,
            tier: tier,
            secondsToReset: TimeInterval(hoursToReset * 3600)
        )
    }

    @Test("safe in mid-band")
    func midBandSafe() {
        // Silver band 600..1500, midpoint ~1050. Progress = 0.5 → safe.
        #expect(compute(weeklyXP: 1050, tier: .silver, hoursToReset: 48) == .safe)
    }

    @Test("eligible when >= 70% through band")
    func eligibleHighProgress() {
        // Silver: 0.7 * (1500-600) + 600 = 1230. Above that → eligible.
        #expect(compute(weeklyXP: 1300, tier: .silver, hoursToReset: 48) == .eligibleForPromotion(xpRemaining: 200))
    }

    @Test("at risk when < 30% and reset is imminent")
    func atRiskLowProgressLateWeek() {
        // Silver: 0.3 * 900 + 600 = 870. Below that and <24h → at risk.
        #expect(compute(weeklyXP: 700, tier: .silver, hoursToReset: 12) == .atRiskOfDemotion)
    }

    @Test("not at risk when low progress but plenty of time left")
    func lowProgressEarlyWeek() {
        #expect(compute(weeklyXP: 700, tier: .silver, hoursToReset: 100) == .safe)
    }

    @Test("bronze never at risk")
    func bronzeNoDemotion() {
        // Bronze, very low XP, <24h → still .safe (bronze can't demote)
        #expect(compute(weeklyXP: 10, tier: .bronze, hoursToReset: 1) == .safe)
    }

    @Test("diamond never promotes")
    func diamondAtTop() {
        // Diamond is top tier → atTop, never .eligibleForPromotion
        #expect(compute(weeklyXP: 10_000, tier: .diamond, hoursToReset: 48) == .atTop)
    }
}
