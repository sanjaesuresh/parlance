// ParlanceTests/SubscriptionTests.swift
import XCTest
@testable import Parlance

final class SubscriptionTests: XCTestCase {
    func testFreeModesMakesSense() {
        XCTAssertEqual(SessionMode.freeModes.count, 2)
        XCTAssertFalse(SessionMode.interview.isProMode)
        XCTAssertFalse(SessionMode.casual.isProMode)
        XCTAssertTrue(SessionMode.pitch.isProMode)
        XCTAssertTrue(SessionMode.keynote.isProMode)
        XCTAssertTrue(SessionMode.debate.isProMode)
        XCTAssertTrue(SessionMode.storytelling.isProMode)
        XCTAssertTrue(SessionMode.explanation.isProMode)
        XCTAssertTrue(SessionMode.negotiation.isProMode)
        XCTAssertTrue(SessionMode.impromptu.isProMode)
        XCTAssertTrue(SessionMode.networking.isProMode)
    }

    func testFreeSessionsPerDayIsLessThanMax() {
        XCTAssertLessThan(AppConstants.freeSessionsPerDay, AppConstants.maxSessionsPerDay)
        XCTAssertEqual(AppConstants.freeSessionsPerDay, 5)
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
            emotionArc: [0.30, 0.25, 0.20, 0.20]
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(EmotionResult.self, from: data)
        XCTAssertEqual(decoded.dominantEmotion, result.dominantEmotion)
        XCTAssertEqual(decoded.confidenceScore, result.confidenceScore, accuracy: 0.001)
        XCTAssertEqual(decoded.emotionArc.count, result.emotionArc.count)
    }

    @MainActor
    func testFreeUserSessionLimitIsEnforced() {
        let vm = HomeViewModel(questionBank: QuestionBankService(questions: []))
        let user = User(displayName: "Test", avatarEmoji: "😀", dailySessionCount: AppConstants.freeSessionsPerDay)
        let result = vm.startSession(
            mode: .interview,
            user: user,
            persistence: PersistenceService.shared,
            wasDailyChallenge: false,
            isPro: false
        )
        XCTAssertNil(result, "Free user at limit should not get a session")
        XCTAssertTrue(vm.showRateLimitAlert)
    }

    @MainActor
    func testProUserExceedsFreeLimit() {
        let vm = HomeViewModel(questionBank: QuestionBankService(questions: []))
        let user = User(displayName: "Pro", avatarEmoji: "😎", dailySessionCount: AppConstants.freeSessionsPerDay)
        // Pro user at the free limit should NOT trigger rate limit alert
        let _ = vm.startSession(
            mode: .interview,
            user: user,
            persistence: PersistenceService.shared,
            wasDailyChallenge: false,
            isPro: true
        )
        XCTAssertFalse(vm.showRateLimitAlert)
    }
}
