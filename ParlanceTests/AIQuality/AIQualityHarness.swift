// ParlanceTests/AIQuality/AIQualityHarness.swift
import Testing
import Foundation
@testable import Parlance

extension Tag {
    @Tag static var aiQuality: Self
}

@Suite(
    "AI Quality Harness",
    .tags(.aiQuality),
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.environment["RUN_AI_QUALITY"] == "1",
        "set RUN_AI_QUALITY=1 to enable — these tests hit the live worker and use API quota"
    )
)
struct AIQualityHarness {

    @Test("scoring fixture", arguments: AIQualityFixtures.all)
    func scoringFixture(fixture: AIQualityFixture) async throws {
        let client = AIQualityTestClient()

        let result: ScoringResult
        do {
            result = try await FeedbackGenerator.fetchScoring(
                client: client,
                mode: fixture.mode,
                level: fixture.level,
                question: fixture.question,
                transcript: fixture.transcript,
                timingStats: fixture.timingStats,
                audioFeatures: fixture.audioFeatures,
                emotionResult: nil
            )
        } catch {
            Issue.record("[\(fixture.id)] scoring call failed: \(error)")
            return
        }

        // Diagnostic: dump full result so failures are debuggable without a re-run.
        printResult(fixture: fixture, result: result)

        // Band failures
        let bandFailures = AIQualityBands.evaluate(fixture.bands, against: result)
        for failure in bandFailures {
            Issue.record("[\(fixture.id)] band: \(failure)")
        }

        // Behavioral check failures
        for check in fixture.checks {
            if let msg = AIQualityChecks.evaluate(check, against: result, transcript: fixture.transcript) {
                Issue.record("[\(fixture.id)] check: \(msg)")
            }
        }
    }

    private func printResult(fixture: AIQualityFixture, result: ScoringResult) {
        // Plain string interpolation — avoids assumptions about Codable conformance
        // on ScoringResult / MetricScore / ScoringMoment.
        print("=== [\(fixture.id)] \(fixture.label) ===")
        print("overallScore: \(result.overallScore)")
        let sortedMetrics = result.metrics.sorted { $0.key < $1.key }
        for (key, value) in sortedMetrics {
            print("  \(key): score=\(value.score) tip=\"\(value.tip)\"")
        }
        print("feedback: \(result.feedback ?? "<nil>")")
        print("bestMoment: \"\(result.bestMoment.quote)\" — \(result.bestMoment.reason)")
        print("worstMoment: \"\(result.worstMoment.quote)\" — \(result.worstMoment.reason)")
    }
}
