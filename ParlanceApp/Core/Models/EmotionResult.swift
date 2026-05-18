// Parlance/Core/Models/EmotionResult.swift
import Foundation

struct EmotionResult: Sendable {
    let dominantEmotion: String
    let dominantScore: Double
    let confidenceScore: Double
    let nervousnessScore: Double
    let enthusiasmScore: Double
    let emotionArc: [Double]
    let topEmotions: [TopEmotion]?
    let emotionTimelines: [String: [Double]]?

    struct TopEmotion: Sendable, Codable, Hashable {
        let name: String
        let score: Double
    }
}

nonisolated extension EmotionResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case dominantEmotion, dominantScore, confidenceScore
        case nervousnessScore, enthusiasmScore, emotionArc
        case topEmotions, emotionTimelines
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dominantEmotion  = try c.decode(String.self,   forKey: .dominantEmotion)
        dominantScore    = try c.decode(Double.self,   forKey: .dominantScore)
        confidenceScore  = try c.decode(Double.self,   forKey: .confidenceScore)
        nervousnessScore = try c.decode(Double.self,   forKey: .nervousnessScore)
        enthusiasmScore  = try c.decode(Double.self,   forKey: .enthusiasmScore)
        emotionArc       = try c.decode([Double].self, forKey: .emotionArc)
        topEmotions      = try c.decodeIfPresent([TopEmotion].self,       forKey: .topEmotions)
        emotionTimelines = try c.decodeIfPresent([String: [Double]].self, forKey: .emotionTimelines)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dominantEmotion,  forKey: .dominantEmotion)
        try c.encode(dominantScore,    forKey: .dominantScore)
        try c.encode(confidenceScore,  forKey: .confidenceScore)
        try c.encode(nervousnessScore, forKey: .nervousnessScore)
        try c.encode(enthusiasmScore,  forKey: .enthusiasmScore)
        try c.encode(emotionArc,       forKey: .emotionArc)
        try c.encodeIfPresent(topEmotions,      forKey: .topEmotions)
        try c.encodeIfPresent(emotionTimelines, forKey: .emotionTimelines)
    }
}
