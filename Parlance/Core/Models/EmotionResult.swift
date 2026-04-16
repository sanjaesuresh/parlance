// Parlance/Core/Models/EmotionResult.swift
import Foundation

struct EmotionResult: Codable {
    /// The highest-scoring emotion label returned by Hume (e.g. "Confidence", "Nervousness").
    let dominantEmotion: String
    /// 0–1 score for the dominant emotion.
    let dominantScore: Double
    /// 0–1 Hume "Confidence" dimension score averaged across segments.
    let confidenceScore: Double
    /// 0–1 Hume "Nervousness" dimension score averaged across segments.
    let nervousnessScore: Double
    /// 0–1 Hume "Excitement" dimension score averaged across segments.
    let enthusiasmScore: Double
    /// Confidence score per segment, in chronological order. Used to show the arc.
    let emotionArc: [Double]
}
