// Parlance/Core/Models/MetricKey.swift
import Foundation

enum MetricKey: String, CaseIterable {
    case fillerWords       = "fillerWords"
    case pace              = "pace"
    case clarity           = "clarity"
    case structure         = "structure"
    case vocabulary        = "vocabulary"
    case relevance         = "relevance"
    case comprehensibility = "comprehensibility"
    case deliveryConfidence = "deliveryConfidence"
    case persuasiveness    = "persuasiveness"
    case engagement        = "engagement"

    var displayName: String {
        switch self {
        case .fillerWords:        return "Filler Words"
        case .pace:               return "Pace"
        case .clarity:            return "Clarity"
        case .structure:          return "Structure"
        case .vocabulary:         return "Vocabulary"
        case .relevance:          return "Relevance"
        case .comprehensibility:  return "Comprehensibility"
        case .deliveryConfidence: return "Delivery Confidence"
        case .persuasiveness:     return "Persuasiveness"
        case .engagement:         return "Engagement"
        }
    }

    var metricDescription: String {
        switch self {
        case .fillerWords:        return "Ums, uhs, and verbal crutches"
        case .pace:               return "Speaking speed and rhythm"
        case .clarity:            return "How easy your words are to follow"
        case .structure:          return "Opening, body, and closing flow"
        case .vocabulary:         return "Word choice strength and variety"
        case .relevance:          return "Did you answer the question?"
        case .comprehensibility:  return "Could a listener follow your reasoning?"
        case .deliveryConfidence: return "Assertiveness without hedging"
        case .persuasiveness:     return "How compelling is your argument?"
        case .engagement:         return "Would a listener stay interested?"
        }
    }

    static let universal: [MetricKey] = [
        .fillerWords, .pace, .clarity, .structure, .vocabulary, .relevance, .comprehensibility
    ]

    static func metrics(for mode: SessionMode) -> [MetricKey] {
        var keys = universal
        switch mode {
        case .interview:    keys += [.deliveryConfidence]
        case .pitch:        keys += [.deliveryConfidence, .persuasiveness]
        case .keynote:      keys += [.deliveryConfidence, .persuasiveness, .engagement]
        case .casual:       keys += [.engagement]
        case .debate:       keys += [.deliveryConfidence, .persuasiveness]
        case .storytelling: keys += [.engagement]
        case .explanation:  keys += [.engagement]
        case .negotiation:  keys += [.deliveryConfidence, .persuasiveness]
        case .impromptu:    keys += [.deliveryConfidence]
        case .networking:   keys += [.engagement]
        }
        return keys
    }
}
