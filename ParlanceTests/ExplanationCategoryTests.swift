// ParlanceTests/ExplanationCategoryTests.swift
import Testing
import Foundation
@testable import Parlance

@Suite("ExplanationCategory")
struct ExplanationCategoryTests {

    @Test("allCases count is 18")
    func allCasesCount() {
        #expect(ExplanationCategory.allCases.count == 18)
    }

    @Test(".any tier is .general")
    func anyTierIsGeneral() {
        #expect(ExplanationCategory.any.tier == .general)
    }

    @Test("9 cases have tier .industry")
    func industryCaseCount() {
        let count = ExplanationCategory.allCases.filter { $0.tier == .industry }.count
        #expect(count == 9)
    }

    @Test("8 cases have tier .knowledge")
    func knowledgeCaseCount() {
        let count = ExplanationCategory.allCases.filter { $0.tier == .knowledge }.count
        #expect(count == 8)
    }

    @Test("displayName for .tech")
    func displayNameTech() {
        #expect(ExplanationCategory.tech.displayName == "Tech / Software")
    }

    @Test("displayName for .realEstate")
    func displayNameRealEstate() {
        #expect(ExplanationCategory.realEstate.displayName == "Real Estate")
    }

    @Test("displayName for .mediaEntertainment")
    func displayNameMediaEntertainment() {
        #expect(ExplanationCategory.mediaEntertainment.displayName == "Media / Entertainment")
    }

    @Test("displayName for .healthWellness")
    func displayNameHealthWellness() {
        #expect(ExplanationCategory.healthWellness.displayName == "Health & Wellness")
    }

    @Test("displayName for .any")
    func displayNameAny() {
        #expect(ExplanationCategory.any.displayName == "Any topic")
    }

    @Test("Codable round-trip for .philosophy")
    func codableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(ExplanationCategory.philosophy)
        let decoded = try JSONDecoder().decode(ExplanationCategory.self, from: encoded)
        #expect(decoded == .philosophy)
    }
}
