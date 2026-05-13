// ParlanceTests/QuestionTests.swift
import Testing
import Foundation
@testable import Parlance

@Suite("Question.category")
@MainActor
struct QuestionCategoryTests {

    @Test("JSON with category decodes correctly")
    func jsonWithCategory_decodesCategory() throws {
        let json = """
        {
            "id": "q_tech_001",
            "mode": "casual",
            "difficultyBand": "1-2",
            "question": "Explain how the internet works.",
            "tips": ["Start simple", "Use analogies", "Build up complexity"],
            "targetDuration": 90,
            "difficultyNote": "Keep it accessible",
            "category": "tech"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let question = try JSONDecoder().decode(Question.self, from: data)
        #expect(question.category == .tech)
    }

    @Test("JSON without category key decodes with nil category")
    func jsonWithoutCategory_decodesNil() throws {
        let json = """
        {
            "id": "q_interview_001",
            "mode": "interview",
            "difficultyBand": "1-2",
            "question": "Tell me about yourself.",
            "tips": ["Use STAR method", "Keep it concise", "Highlight achievements"],
            "targetDuration": 60,
            "difficultyNote": "Focus on structure"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let question = try JSONDecoder().decode(Question.self, from: data)
        #expect(question.category == nil)
    }
}
