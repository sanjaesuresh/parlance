import Testing
@testable import Parlance

@Suite("SessionMode.realLife")
struct SessionModeRealLifeTests {

    @Test("realLife is a Pro mode")
    func realLifeIsProMode() {
        #expect(SessionMode.realLife.isProMode == true)
    }

    @Test("realLife is not in defaultModes")
    func realLifeNotInDefaultModes() {
        #expect(SessionMode.defaultModes.contains(.realLife) == false)
    }

    @Test("realLife leads non-free modes in allCases")
    func realLifeLeadsProModes() {
        let pro = SessionMode.allCases.filter { !SessionMode.freeModes.contains($0) }
        #expect(pro.first == .realLife)
    }

    @Test("realLife display metadata is set")
    func realLifeMetadata() {
        #expect(SessionMode.realLife.displayName == "Real Life")
        #expect(SessionMode.realLife.emoji == "🎯")
        #expect(SessionMode.realLife.description.isEmpty == false)
    }

    @Test("dailyChallengeMode never returns realLife")
    func dailyChallengeNeverPicksRealLife() {
        for day in 1...366 {
            #expect(SessionMode.dailyChallengeMode(dayOfYear: day) != .realLife)
        }
    }
}
