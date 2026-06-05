// Parlance/Features/Results/ResultsViewModel.swift
import Combine
import SwiftUI

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var isRetryingFeedback = false

    func retryFeedback(for session: Session, question: String) async {
        isRetryingFeedback = true
        defer { isRetryingFeedback = false }

        let client = FeedbackClient(baseURL: AppConstants.apiBaseURL)

        // Derive approximate timing from the stored transcript so the AI
        // doesn't see "0 words" and fall back to scoring everything 1-2.
        let wordCount = session.transcript.split(separator: " ").count
        let approxTiming = TimingStats(
            wordCount: wordCount,
            speechToSilenceRatio: 0.75,
            longestPauseDuration: 0,
            longestPauseAfterWord: "",
            speakingRateStdDev: 0
        )

        guard let result = try? await FeedbackGenerator.fetchScoring(
            client: client,
            mode: session.mode,
            level: session.difficultyLevel,
            question: question,
            transcript: session.transcript,
            timingStats: approxTiming,
            audioFeatures: AudioFeatures.empty
        ) else { return }

        session.metricScores = result.metrics.mapValues(\.score)
        session.metricTips = result.metrics.mapValues(\.tip)
        session.overallScore = result.overallScore
        session.aiCoachFeedback = result.feedback
        session.bestMomentQuote = result.bestMoment.quote
        session.bestMomentReason = result.bestMoment.reason
        session.worstMomentQuote = result.worstMoment.quote
        session.worstMomentReason = result.worstMoment.reason
    }
}
