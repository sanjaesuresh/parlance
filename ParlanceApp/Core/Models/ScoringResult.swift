// Parlance/Core/Models/ScoringResult.swift
import Foundation

struct MetricScore: Codable {
    let score: Int  // 0-10
    let tip: String
}

struct ScoringMoment: Codable {
    let quote: String
    let reason: String
}

struct ScoringResult: Codable {
    let metrics: [String: MetricScore]
    let overallScore: Int  // 0-100
    let feedback: String?
    let bestMoment: ScoringMoment
    let worstMoment: ScoringMoment
    /// 0-100. How directly the user's response addressed the prompt asked.
    /// Optional for backwards compatibility with older payloads.
    let relevanceToPrompt: Int?
}
