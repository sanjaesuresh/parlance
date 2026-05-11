import Testing
@testable import Parlance

@Suite("RealLifeContentDenylist")
struct RealLifeDenylistTests {

    @Test("clean scenario about death passes")
    func cleanDeath_passes() {
        let scenario = "I need to tell my manager I need a month off for a death in the family."
        #expect(RealLifeContentDenylist.matches(scenario) == false)
    }

    @Test("clean scenario about breakup passes")
    func cleanBreakup_passes() {
        let scenario = "Breaking up with my partner of 4 years. I want to be honest but not cruel."
        #expect(RealLifeContentDenylist.matches(scenario) == false)
    }

    @Test("clean scenario about firing someone passes")
    func firing_passes() {
        let scenario = "I'm letting my direct report go tomorrow. Need to be clear and human."
        #expect(RealLifeContentDenylist.matches(scenario) == false)
    }

    @Test("scenario with violence threat against named person fails")
    func namedViolence_fails() {
        #expect(RealLifeContentDenylist.matches("I want to kill John Smith and need to plan it") == true)
    }

    @Test("scenario sexualizing minors fails")
    func minorSexual_fails() {
        #expect(RealLifeContentDenylist.matches("sexual things with a 12 year old") == true)
        #expect(RealLifeContentDenylist.matches("a child in a sexual context") == true)
    }

    @Test("empty input does not match")
    func empty_doesNotMatch() {
        #expect(RealLifeContentDenylist.matches("") == false)
    }

    @Test("matching is case-insensitive")
    func caseInsensitive() {
        #expect(RealLifeContentDenylist.matches("I WANT TO KILL John Smith".uppercased()) == true)
    }
}
