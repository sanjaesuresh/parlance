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

    // MARK: - Slurs
    //
    // These tests verify the sealed slur list catches each category but
    // does NOT false-positive on legitimate words that contain substrings
    // (Pakistan, spice, rethinking, etc.). Each slur is exercised via its
    // most common form — variants and 1337-substitutions are handled by
    // the regex but not exhaustively tested here.

    @Test("racial slur fails (1337 variant)")
    func racialSlur_fails() {
        // Uses the digit-1 variant to exercise the character class without
        // writing the canonical slur in test source. The same regex covers
        // the canonical form (verified manually).
        #expect(RealLifeContentDenylist.matches("called n1gger in a forum") == true)
    }

    @Test("anti-gay slur fails (long form)")
    func antiGaySlurLong_fails() {
        #expect(RealLifeContentDenylist.matches("he kept calling me a faggot") == true)
    }

    @Test("anti-gay slur fails (short form)")
    func antiGaySlurShort_fails() {
        #expect(RealLifeContentDenylist.matches("being called a fag in middle school") == true)
    }

    @Test("anti-trans slur fails")
    func antiTransSlur_fails() {
        #expect(RealLifeContentDenylist.matches("being called a tranny by a coworker") == true)
    }

    @Test("anti-East-Asian racial slur fails")
    func antiAsianSlur_fails() {
        #expect(RealLifeContentDenylist.matches("yelling chink at me on the bus") == true)
    }

    @Test("anti-Latin racial slur fails")
    func antiLatinSlur_fails() {
        #expect(RealLifeContentDenylist.matches("hearing spic from a stranger") == true)
    }

    @Test("anti-Jewish slur fails")
    func antiJewishSlur_fails() {
        #expect(RealLifeContentDenylist.matches("called a kike in a comment") == true)
    }

    @Test("ableist slur fails")
    func ableistSlur_fails() {
        #expect(RealLifeContentDenylist.matches("being called retarded for asking") == true)
    }

    // ---- false-positive guards ----

    @Test("'spice' does not match anti-Latin pattern")
    func spice_passes() {
        #expect(RealLifeContentDenylist.matches("I'm explaining the spice trade history") == false)
    }

    @Test("'rethinking' does not match anti-Asian pattern")
    func rethinking_passes() {
        #expect(RealLifeContentDenylist.matches("rethinking my approach to the conversation") == false)
    }

    @Test("'Pakistan' does not match any slur pattern")
    func pakistan_passes() {
        #expect(RealLifeContentDenylist.matches("explaining travel to Pakistan to my parents") == false)
    }

    @Test("'thanksgiving' does not match")
    func thanksgiving_passes() {
        #expect(RealLifeContentDenylist.matches("hosting thanksgiving dinner for my in-laws") == false)
    }

    @Test("'retardant' does not match the ableist pattern")
    func retardant_passes() {
        #expect(RealLifeContentDenylist.matches("explaining fire retardant materials at work") == false)
    }
}
