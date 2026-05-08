// ParlanceTests/AIQuality/AIQualityChecks.swift
import Foundation
@testable import Parlance

/// Pure functions that evaluate a `BehavioralCheck` against a `ScoringResult`.
/// Returns `nil` on pass, or a human-readable failure string on fail.
enum AIQualityChecks {

    static func evaluate(
        _ check: BehavioralCheck,
        against result: ScoringResult,
        transcript: String
    ) -> String? {
        switch check {

        case .feedbackContainsAnyOf(let phrases):
            let feedback = (result.feedback ?? "").lowercased()
            let lowered = phrases.map { $0.lowercased() }
            if lowered.contains(where: { feedback.contains($0) }) {
                return nil
            }
            return "feedback did not contain any of \(phrases): feedback=\"\(result.feedback ?? "<nil>")\""

        case .bestMomentQuoteInTranscript:
            return quoteInTranscript(
                quote: result.bestMoment.quote, transcript: transcript, label: "bestMoment.quote"
            )

        case .worstMomentQuoteInTranscript:
            return quoteInTranscript(
                quote: result.worstMoment.quote, transcript: transcript, label: "worstMoment.quote"
            )

        case .allMetricsAtMost(let max):
            for (key, score) in result.metrics where score.score > max {
                return "metric \(key) scored \(score.score), expected ≤ \(max)"
            }
            return nil

        case .allMetricsAtLeast(let min):
            for (key, score) in result.metrics where score.score < min {
                return "metric \(key) scored \(score.score), expected ≥ \(min)"
            }
            return nil

        case .metricInRange(let key, let range):
            guard let entry = result.metrics[key.rawValue] else {
                return "metric \(key.rawValue) missing from result.metrics (found: \(Array(result.metrics.keys).sorted()))"
            }
            if range.contains(entry.score) { return nil }
            return "metric \(key.rawValue) scored \(entry.score), expected in \(range.lowerBound)...\(range.upperBound)"
        }
    }

    private static func quoteInTranscript(quote: String, transcript: String, label: String) -> String? {
        // Empty quote = trivially passes.
        guard !quote.isEmpty else { return nil }
        if transcript.lowercased().contains(quote.lowercased()) {
            return nil
        }
        return "\(label) \"\(quote)\" not found in transcript — likely a hallucinated quote"
    }
}

/// Evaluates an `ExpectedBands` value. Returns failure messages (one per failed band), or [] on pass.
enum AIQualityBands {
    static func evaluate(_ bands: ExpectedBands, against result: ScoringResult) -> [String] {
        var failures: [String] = []
        if let overallRange = bands.overall, !overallRange.contains(result.overallScore) {
            failures.append("overallScore \(result.overallScore) outside expected \(overallRange.lowerBound)...\(overallRange.upperBound)")
        }
        for (key, range) in bands.metrics {
            guard let entry = result.metrics[key.rawValue] else {
                failures.append("metric \(key.rawValue) missing — expected score in \(range.lowerBound)...\(range.upperBound)")
                continue
            }
            if !range.contains(entry.score) {
                failures.append("metric \(key.rawValue) scored \(entry.score), outside expected \(range.lowerBound)...\(range.upperBound)")
            }
        }
        return failures
    }
}
