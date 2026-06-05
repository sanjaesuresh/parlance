// ParlanceTests/SubscriptionTests.swift
import XCTest
import SwiftData
@testable import Parlance

final class SubscriptionTests: XCTestCase {
    func testFreeModesMakesSense() {
        XCTAssertEqual(SessionMode.freeModes.count, 6)
        XCTAssertFalse(SessionMode.interview.isProMode)
        XCTAssertFalse(SessionMode.casual.isProMode)
        XCTAssertFalse(SessionMode.impromptu.isProMode)
        XCTAssertFalse(SessionMode.explanation.isProMode)
        XCTAssertFalse(SessionMode.networking.isProMode)
        XCTAssertFalse(SessionMode.pitch.isProMode)
        XCTAssertTrue(SessionMode.keynote.isProMode)
        XCTAssertTrue(SessionMode.debate.isProMode)
        XCTAssertTrue(SessionMode.storytelling.isProMode)
        XCTAssertTrue(SessionMode.negotiation.isProMode)
        XCTAssertTrue(SessionMode.realLife.isProMode)
    }

    func testFreeSessionsPerDayIsTwo() {
        XCTAssertEqual(AppConstants.freeSessionsPerDay, 2)
    }

    func testProProductIDIsSet() {
        XCTAssertEqual(AppConstants.proProductID, "com.parlance.pro.monthly")
    }

    func testEmotionResultDecoding() throws {
        let json = """
        {
            "dominantEmotion": "Confidence",
            "dominantScore": 0.72,
            "confidenceScore": 0.72,
            "nervousnessScore": 0.31,
            "enthusiasmScore": 0.45,
            "emotionArc": [0.15, 0.35, 0.58, 0.72]
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(EmotionResult.self, from: json)
        XCTAssertEqual(result.dominantEmotion, "Confidence")
        XCTAssertEqual(result.confidenceScore, 0.72, accuracy: 0.001)
        XCTAssertEqual(result.emotionArc.count, 4)
    }

    func testEmotionResultRoundTrip() throws {
        let result = EmotionResult(
            dominantEmotion: "Nervousness",
            dominantScore: 0.65,
            confidenceScore: 0.20,
            nervousnessScore: 0.65,
            enthusiasmScore: 0.30,
            emotionArc: [0.30, 0.25, 0.20, 0.20],
            topEmotions: nil,
            emotionTimelines: nil
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(EmotionResult.self, from: data)
        XCTAssertEqual(decoded.dominantEmotion, result.dominantEmotion)
        XCTAssertEqual(decoded.confidenceScore, result.confidenceScore, accuracy: 0.001)
        XCTAssertEqual(decoded.emotionArc.count, result.emotionArc.count)
    }

    @MainActor
    func testFreeUserSessionLimitIsEnforced() async {
        let persistence = PersistenceService.forTesting()
        let user = User(displayName: "Test", avatarEmoji: "😀", dailySessionCount: AppConstants.freeSessionsPerDay)
        persistence.context.insert(user)
        let vm = HomeViewModel(questionBank: QuestionBankService(questions: []))
        let result = vm.startSession(
            mode: .interview,
            user: user,
            persistence: persistence,
            wasDailyChallenge: false,
            isPro: false
        )
        XCTAssertNil(result, "Free user at limit should not get a session")
        XCTAssertTrue(vm.showRateLimitAlert)
    }

    @MainActor
    func testProUserExceedsFreeLimit() async {
        let persistence = PersistenceService.forTesting()
        let user = User(displayName: "Pro", avatarEmoji: "😎", dailySessionCount: AppConstants.freeSessionsPerDay)
        persistence.context.insert(user)
        let vm = HomeViewModel(questionBank: QuestionBankService(questions: []))
        let _ = vm.startSession(
            mode: .interview,
            user: user,
            persistence: persistence,
            wasDailyChallenge: false,
            isPro: true
        )
        XCTAssertFalse(vm.showRateLimitAlert)
    }
}
