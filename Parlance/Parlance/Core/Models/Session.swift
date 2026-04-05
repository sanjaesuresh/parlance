import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var date: Date
    var modeRaw: String
    var difficultyLevel: Int
    var duration: TimeInterval
    var transcript: String
    var overallScore: Int
    var fillerCount: Int
    var paceScore: Int
    var clarityScore: Int
    var structureScore: Int
    var vocabularyScore: Int
    var question: String
    var aiCoachFeedback: String?
    var bestMomentTimestamp: TimeInterval
    var bestMomentText: String
    var worstMomentTimestamp: TimeInterval
    var worstMomentText: String
    var xpEarned: Int
    var wasDailyChallenge: Bool

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .interview }
        set { modeRaw = newValue.rawValue }
    }

    var hasTranscript: Bool { !transcript.isEmpty }

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
    }
}
