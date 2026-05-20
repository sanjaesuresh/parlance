// ParlanceTests/ScoringResultRelevanceTests.swift
import XCTest
@testable import Parlance

final class ScoringResultRelevanceTests: XCTestCase {
    func testDecodesRelevanceField() throws {
        let json = """
        {
          "metrics": {"fillerWords": {"score": 8, "tip": "keep it up"}},
          "overallScore": 75,
          "relevanceToPrompt": 80,
          "feedback": "Great",
          "bestMoment": {"quote": "good", "reason": "clear"},
          "worstMoment": {"quote": "bad", "reason": "rambled"}
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ScoringResult.self, from: json)
        XCTAssertEqual(result.relevanceToPrompt, 80)
    }

    func testDecodesWhenRelevanceMissing() throws {
        let json = """
        {
          "metrics": {},
          "overallScore": 50,
          "feedback": null,
          "bestMoment": {"quote": "", "reason": ""},
          "worstMoment": {"quote": "", "reason": ""}
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ScoringResult.self, from: json)
        XCTAssertNil(result.relevanceToPrompt)
    }
}
