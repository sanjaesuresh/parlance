// ParlanceTests/AIQuality/AIQualityFixture.swift
import Foundation
@testable import Parlance

/// One curated test case for the AI scoring pipeline.
struct AIQualityFixture {
    let id: String
    let label: String
    let mode: SessionMode
    let level: Int
    let question: String
    let transcript: String
    let timingStats: TimingStats
    let audioFeatures: AudioFeatures
    let bands: ExpectedBands
    let checks: [BehavioralCheck]
}

/// Optional score-band bounds. If both fields are nil/empty, no band assertions run.
struct ExpectedBands {
    var overall: ClosedRange<Int>? = nil
    var metrics: [MetricKey: ClosedRange<Int>] = [:]

    static let none = ExpectedBands()
}

/// Behavioral assertions evaluated against a returned ScoringResult.
enum BehavioralCheck {
    /// `feedback` (case-insensitive) contains at least one of the given phrases.
    case feedbackContainsAnyOf([String])
    /// `bestMoment.quote` is a non-empty substring of the input transcript.
    case bestMomentQuoteInTranscript
    /// `worstMoment.quote` is a non-empty substring of the input transcript.
    case worstMomentQuoteInTranscript
    /// Every metric in `metrics` has `score <= max`.
    case allMetricsAtMost(Int)
    /// Every metric in `metrics` has `score >= min`.
    case allMetricsAtLeast(Int)
    /// The given metric's score is in the given range. Fails if metric is missing.
    case metricInRange(MetricKey, ClosedRange<Int>)
}
