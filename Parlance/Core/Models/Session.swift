// Parlance/Core/Models/Session.swift
import Foundation
import SwiftData

@Model
final class Session {
    // MARK: - Core identity
    var id: UUID
    var date: Date
    var modeRaw: String
    var difficultyLevel: Int
    var duration: TimeInterval
    var transcript: String
    var overallScore: Int
    var fillerCount: Int
    var question: String
    var xpEarned: Int
    var wasDailyChallenge: Bool
    var aiCoachFeedback: String?

    // MARK: - Legacy metric scores (kept for existing sessions)
    var paceScore: Int
    var clarityScore: Int
    var structureScore: Int
    var vocabularyScore: Int

    // MARK: - Legacy moments (kept for existing sessions)
    var bestMomentTimestamp: TimeInterval
    var bestMomentText: String
    var worstMomentTimestamp: TimeInterval
    var worstMomentText: String

    // MARK: - New: AI metric scores (JSON-encoded [String: Int])
    var metricScoresData: Data?
    // MARK: - New: AI metric tips (JSON-encoded [String: String])
    var metricTipsData: Data?

    // MARK: - Emotion analysis (Pro only; nil for free-tier sessions)
    var emotionResultData: Data?

    // MARK: - New: AI moments
    var bestMomentQuote: String = ""
    var bestMomentReason: String = ""
    var worstMomentQuote: String = ""
    var worstMomentReason: String = ""

    // MARK: - Computed

    var emotionResult: EmotionResult? {
        get {
            guard let data = emotionResultData else { return nil }
            return try? JSONDecoder().decode(EmotionResult.self, from: data)
        }
        set {
            if let v = newValue {
                emotionResultData = try? JSONEncoder().encode(v)
            } else {
                emotionResultData = nil
            }
        }
    }

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .interview }
        set { modeRaw = newValue.rawValue }
    }

    var hasTranscript: Bool { !transcript.isEmpty }

    /// True if this session was scored by the new AI pipeline and has non-empty metric data.
    var isAIScored: Bool {
        guard let data = metricScoresData else { return false }
        return data.count > 2
    }

    var metricScores: [String: Int] {
        get {
            guard let data = metricScoresData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            metricScoresData = try? JSONEncoder().encode(newValue)
        }
    }

    var metricTips: [String: String] {
        get {
            guard let data = metricTipsData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            metricTipsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Init for new AI-scored sessions

    init(
        mode: SessionMode,
        difficultyLevel: Int,
        duration: TimeInterval,
        transcript: String,
        fillerCount: Int,
        question: String,
        scoringResult: ScoringResult,
        xpEarned: Int,
        wasDailyChallenge: Bool,
        emotionResult: EmotionResult? = nil
    ) {
        self.id = UUID()
        self.date = .now
        self.modeRaw = mode.rawValue
        self.difficultyLevel = difficultyLevel
        self.duration = duration
        self.transcript = transcript
        self.fillerCount = fillerCount
        self.question = question
        self.xpEarned = xpEarned
        self.wasDailyChallenge = wasDailyChallenge

        self.overallScore = scoringResult.overallScore
        self.aiCoachFeedback = scoringResult.feedback

        let scores = scoringResult.metrics.mapValues(\.score)
        let tips = scoringResult.metrics.mapValues(\.tip)
        self.metricScoresData = try? JSONEncoder().encode(scores)
        self.metricTipsData = try? JSONEncoder().encode(tips)
        self.bestMomentQuote = scoringResult.bestMoment.quote
        self.bestMomentReason = scoringResult.bestMoment.reason
        self.worstMomentQuote = scoringResult.worstMoment.quote
        self.worstMomentReason = scoringResult.worstMoment.reason
        if let er = emotionResult {
            self.emotionResultData = try? JSONEncoder().encode(er)
        } else {
            self.emotionResultData = nil
        }

        // Legacy fields — zero for new sessions
        self.paceScore = 0
        self.clarityScore = 0
        self.structureScore = 0
        self.vocabularyScore = 0
        self.bestMomentTimestamp = 0
        self.bestMomentText = ""
        self.worstMomentTimestamp = 0
        self.worstMomentText = ""
    }

    // MARK: - Legacy init (kept so existing code still compiles during migration)

    init(
        mode: SessionMode,
        difficultyLevel: Int,
        duration: TimeInterval,
        transcript: String,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        question: String,
        aiCoachFeedback: String? = nil,
        bestMomentTimestamp: TimeInterval = 0,
        bestMomentText: String = "",
        worstMomentTimestamp: TimeInterval = 0,
        worstMomentText: String = "",
        xpEarned: Int,
        wasDailyChallenge: Bool
    ) {
        self.id = UUID()
        self.date = .now
        self.modeRaw = mode.rawValue
        self.difficultyLevel = difficultyLevel
        self.duration = duration
        self.transcript = transcript
        self.overallScore = overallScore
        self.fillerCount = fillerCount
        self.paceScore = paceScore
        self.clarityScore = clarityScore
        self.structureScore = structureScore
        self.vocabularyScore = vocabularyScore
        self.question = question
        self.aiCoachFeedback = aiCoachFeedback
        self.bestMomentTimestamp = bestMomentTimestamp
        self.bestMomentText = bestMomentText
        self.worstMomentTimestamp = worstMomentTimestamp
        self.worstMomentText = worstMomentText
        self.xpEarned = xpEarned
        self.wasDailyChallenge = wasDailyChallenge
        self.metricScoresData = nil
        self.metricTipsData = nil
        self.emotionResultData = nil
        self.bestMomentQuote = ""
        self.bestMomentReason = ""
        self.worstMomentQuote = ""
        self.worstMomentReason = ""
    }
}
