import Testing
import Foundation
@testable import Parlance

@Suite("FeedbackGenerator — Real Life")
struct FeedbackGeneratorRealLifeTests {

    private func prompt(mode: SessionMode, question: String) -> String {
        FeedbackGenerator.buildPrompt(
            mode: mode,
            level: 5,
            question: question,
            transcript: "I'm taking a month off starting Monday. The arrangements need attention.",
            timingStats: .empty,
            audioFeatures: .empty,
            emotionResult: nil
        )
    }

    @Test("realLife wraps question in user_scenario tags")
    func realLifeWrapsScenario() {
        let p = prompt(
            mode: .realLife,
            question: "Telling my manager I need a month off for a death in the family."
        )
        #expect(p.contains("<user_scenario>"))
        #expect(p.contains("</user_scenario>"))
        #expect(p.contains("Telling my manager"))
    }

    @Test("realLife includes untrusted-data instruction")
    func realLifeIncludesUntrustedInstruction() {
        let p = prompt(mode: .realLife, question: "Anything")
        #expect(p.localizedCaseInsensitiveContains("untrusted"))
    }

    @Test("non-realLife modes do not wrap question in tags")
    func interviewDoesNotWrap() {
        let p = prompt(mode: .interview, question: "Tell me about yourself.")
        #expect(p.contains("<user_scenario>") == false)
    }
}
