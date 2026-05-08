// ParlanceTests/QuestionBankServiceTests.swift
import Testing
import Foundation
@testable import Parlance

// MARK: - Helpers

private func makeQ(
    id: String,
    mode: SessionMode = .explanation,
    band: String = "5-6",
    category: ExplanationCategory? = nil
) -> Question {
    Question(
        id: id,
        mode: mode,
        difficultyBand: band,
        question: "Test",
        tips: ["a", "b", "c"],
        targetDuration: 90,
        difficultyNote: "Test",
        category: category
    )
}

// MARK: - QuestionBankService category-aware selection

@Suite("QuestionBankService category-aware selection")
struct QuestionBankServiceTests {

    @Test("category filter returns only matching category")
    func test_categoryFilter_returnsOnlyMatchingCategory() {
        let bank = QuestionBankService(questions: [
            makeQ(id: "tech_1", category: .tech),
            makeQ(id: "tech_2", category: .tech),
            makeQ(id: "health_1", category: .healthcare),
        ])

        for _ in 0..<10 {
            let result = bank.selectQuestion(
                mode: .explanation,
                band: "5-6",
                category: .tech,
                excludingIds: []
            )
            #expect(result?.category == .tech)
        }
    }

    @Test("any category returns from any bucket")
    func test_anyCategory_returnsFromAnyBucket() {
        let bank = QuestionBankService(questions: [
            makeQ(id: "tech_1", category: .tech),
            makeQ(id: "health_1", category: .healthcare),
        ])

        var seen: Set<ExplanationCategory> = []
        for _ in 0..<50 {
            if let result = bank.selectQuestion(
                mode: .explanation,
                band: "5-6",
                category: .any,
                excludingIds: []
            ) {
                if let cat = result.category {
                    seen.insert(cat)
                }
            }
        }

        #expect(seen.contains(.tech))
        #expect(seen.contains(.healthcare))
    }

    @Test("fallback (a) re-serves same category when all same-category questions seen")
    func test_fallback_a_returnsSeenSameCategory_whenAllSeen() {
        let bank = QuestionBankService(questions: [
            makeQ(id: "tech_1", category: .tech),
            makeQ(id: "health_1", category: .healthcare),
        ])

        // tech_1 is in excludingIds — only tech question is "seen"
        // fallback (a): same category, ignore seen → must return tech_1, not health_1
        let result = bank.selectQuestion(
            mode: .explanation,
            band: "5-6",
            category: .tech,
            excludingIds: ["tech_1"]
        )

        #expect(result?.id == "tech_1")
    }

    @Test("fallback (b) returns any unseen when requested category has no questions")
    func test_fallback_b_returnsAnyUnseen_whenCategoryEmpty() {
        let bank = QuestionBankService(questions: [
            makeQ(id: "health_1", category: .healthcare),
        ])

        // No tech questions exist at all → fall back to any unseen
        let result = bank.selectQuestion(
            mode: .explanation,
            band: "5-6",
            category: .tech,
            excludingIds: []
        )

        #expect(result?.id == "health_1")
    }

    @Test("non-explanation mode ignores category param")
    func test_nonExplanationMode_ignoresCategory() {
        let bank = QuestionBankService(questions: [
            makeQ(id: "interview_1", mode: .interview, category: nil),
        ])

        let result = bank.selectQuestion(
            mode: .interview,
            band: "5-6",
            category: .tech,
            excludingIds: []
        )

        #expect(result?.id == "interview_1")
    }

    @Test("returns nil when no questions exist at band")
    func test_returnsNil_whenNoQuestionsAtBand() {
        let bank = QuestionBankService(questions: [])

        let result = bank.selectQuestion(
            mode: .explanation,
            band: "5-6",
            category: .tech,
            excludingIds: []
        )

        #expect(result == nil)
    }
}
