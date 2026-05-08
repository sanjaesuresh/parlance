// Parlance/Core/Models/EmotionResult.swift
import Foundation

struct EmotionResult: Sendable {
    let dominantEmotion: String
    let dominantScore: Double
    let confidenceScore: Double
    let nervousnessScore: Double
    let enthusiasmScore: Double
    let emotionArc: [Double]
}

nonisolated extension EmotionResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case dominantEmotion, dominantScore, confidenceScore
        case nervousnessScore, enthusiasmScore, emotionArc
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dominantEmotion  = try c.decode(String.self,   forKey: .dominantEmotion)
        dominantScore    = try c.decode(Double.self,   forKey: .dominantScore)
        confidenceScore  = try c.decode(Double.self,   forKey: .confidenceScore)
        nervousnessScore = try c.decode(Double.self,   forKey: .nervousnessScore)
        enthusiasmScore  = try c.decode(Double.self,   forKey: .enthusiasmScore)
        emotionArc       = try c.decode([Double].self, forKey: .emotionArc)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dominantEmotion,  forKey: .dominantEmotion)
        try c.encode(dominantScore,    forKey: .dominantScore)
        try c.encode(confidenceScore,  forKey: .confidenceScore)
        try c.encode(nervousnessScore, forKey: .nervousnessScore)
        try c.encode(enthusiasmScore,  forKey: .enthusiasmScore)
        try c.encode(emotionArc,       forKey: .emotionArc)
    }
}
