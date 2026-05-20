// ParlanceTests/AIQuality/AIQualityChecksTests.swift
import Testing
import Foundation
@testable import Parlance

@Suite("AIQualityChecks.evaluate")
struct AIQualityChecksTests {

    private func makeResult(
        metrics: [MetricKey: Int] = [:],
        overall: Int = 70,
        feedback: String? = "Solid answer. Work on opening.",
        bestQuote: String = "I led the migration",
        worstQuote: String = "and then um yeah"
    ) -> ScoringResult {
        let metricDict: [String: MetricScore] = Dictionary(
            uniqueKeysWithValues: metrics.map { ($0.key.rawValue, MetricScore(score: $0.value, tip: "")) }
        )
        return ScoringResult(
            metrics: metricDict,
            overallScore: overall,
            feedback: feedback,
            bestMoment: ScoringMoment(quote: bestQuote, reason: ""),
            worstMoment: ScoringMoment(quote: worstQuote, reason: ""),
            relevanceToPrompt: nil
        )
    }

    // MARK: - feedbackContainsAnyOf

    @Test("feedbackContainsAnyOf passes when any phrase matches case-insensitively")
    func feedbackContainsAnyOf_matches() {
        let result = makeResult(feedback: "Watch your fillers — too many ums.")
        let failure = AIQualityChecks.evaluate(
            .feedbackContainsAnyOf(["filler", "uh"]),
            against: result, transcript: ""
        )
        #expect(failure == nil)
    }

    @Test("feedbackContainsAnyOf fails with descriptive message when none match")
    func feedbackContainsAnyOf_fails() {
        let result = makeResult(feedback: "Strong answer overall.")
        let failure = AIQualityChecks.evaluate(
            .feedbackContainsAnyOf(["hook", "urgency"]),
            against: result, transcript: ""
        )
        #expect(failure != nil)
        #expect(failure?.contains("hook") == true)
    }

    @Test("feedbackContainsAnyOf fails when feedback is nil")
    func feedbackContainsAnyOf_nilFeedback() {
        let result = makeResult(feedback: nil)
        let failure = AIQualityChecks.evaluate(
            .feedbackContainsAnyOf(["anything"]),
            against: result, transcript: ""
        )
        #expect(failure != nil)
    }

    // MARK: - bestMomentQuoteInTranscript

    @Test("bestMomentQuoteInTranscript passes when quote is a substring")
    func bestQuoteInTranscript_passes() {
        let result = makeResult(bestQuote: "led the migration")
        let failure = AIQualityChecks.evaluate(
            .bestMomentQuoteInTranscript,
            against: result, transcript: "I led the migration successfully."
        )
        #expect(failure == nil)
    }

    @Test("bestMomentQuoteInTranscript fails on hallucinated quote")
    func bestQuoteInTranscript_fails() {
        let result = makeResult(bestQuote: "I am an astronaut")
        let failure = AIQualityChecks.evaluate(
            .bestMomentQuoteInTranscript,
            against: result, transcript: "I led the migration successfully."
        )
        #expect(failure != nil)
        #expect(failure?.lowercased().contains("transcript") == true)
    }

    @Test("bestMomentQuoteInTranscript passes trivially on empty quote (nothing to check)")
    func bestQuoteInTranscript_emptyQuote() {
        let result = makeResult(bestQuote: "")
        let failure = AIQualityChecks.evaluate(
            .bestMomentQuoteInTranscript,
            against: result, transcript: "anything"
        )
        #expect(failure == nil)
    }

    // MARK: - worstMomentQuoteInTranscript (mirrors best)

    @Test("worstMomentQuoteInTranscript passes when quote is a substring")
    func worstQuoteInTranscript_passes() {
        let result = makeResult(worstQuote: "um yeah")
        let failure = AIQualityChecks.evaluate(
            .worstMomentQuoteInTranscript,
            against: result, transcript: "and then um yeah we shipped"
        )
        #expect(failure == nil)
    }

    // MARK: - allMetricsAtMost / allMetricsAtLeast

    @Test("allMetricsAtMost passes when every metric is below the cap")
    func allMetricsAtMost_passes() {
        let result = makeResult(metrics: [.clarity: 1, .pace: 2])
        let failure = AIQualityChecks.evaluate(
            .allMetricsAtMost(2),
            against: result, transcript: ""
        )
        #expect(failure == nil)
    }

    @Test("allMetricsAtMost fails when any metric exceeds the cap")
    func allMetricsAtMost_fails() {
        let result = makeResult(metrics: [.clarity: 1, .pace: 5])
        let failure = AIQualityChecks.evaluate(
            .allMetricsAtMost(2),
            against: result, transcript: ""
        )
        #expect(failure != nil)
    }

    @Test("allMetricsAtLeast fails when any metric is below the floor")
    func allMetricsAtLeast_fails() {
        let result = makeResult(metrics: [.clarity: 8, .pace: 4])
        let failure = AIQualityChecks.evaluate(
            .allMetricsAtLeast(5),
            against: result, transcript: ""
        )
        #expect(failure != nil)
    }

    // MARK: - metricInRange

    @Test("metricInRange passes when score is in range")
    func metricInRange_passes() {
        let result = makeResult(metrics: [.structure: 8])
        let failure = AIQualityChecks.evaluate(
            .metricInRange(.structure, 7...10),
            against: result, transcript: ""
        )
        #expect(failure == nil)
    }

    @Test("metricInRange fails when score is out of range")
    func metricInRange_fails() {
        let result = makeResult(metrics: [.structure: 4])
        let failure = AIQualityChecks.evaluate(
            .metricInRange(.structure, 7...10),
            against: result, transcript: ""
        )
        #expect(failure != nil)
    }

    @Test("metricInRange fails when metric is missing entirely")
    func metricInRange_missing() {
        let result = makeResult(metrics: [.clarity: 7])
        let failure = AIQualityChecks.evaluate(
            .metricInRange(.structure, 7...10),
            against: result, transcript: ""
        )
        #expect(failure != nil)
        #expect(failure?.lowercased().contains("missing") == true || failure?.lowercased().contains("not found") == true)
    }
}

@Suite("AIQualityFixtures")
struct AIQualityFixturesSanityTests {

    @Test("all fixtures have a non-empty id")
    func nonEmptyIds() {
        for f in AIQualityFixtures.all {
            #expect(!f.id.isEmpty)
        }
    }

    @Test("fixture ids are unique")
    func uniqueIds() {
        let ids = AIQualityFixtures.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("seed corpus has at least 30 fixtures")
    func sizeIsCalibrated() {
        #expect(AIQualityFixtures.all.count >= 30)
    }
}
