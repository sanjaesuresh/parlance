import Foundation

enum FeedbackGenerator {

    static func buildPrompt(
        mode: SessionMode,
        level: Int,
        question: String,
        duration: TimeInterval,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        transcript: String
    ) -> String {
        let levelName = DifficultyLevel.name(for: level)
        let excerptWords = transcript.split(separator: " ").prefix(AppConstants.transcriptExcerptLength)
        let excerpt = excerptWords.joined(separator: " ")

        return """
        You are a direct, no-nonsense speech coach. A user just completed a \(mode.displayName) speaking session at level \(level) (\(levelName)).

        They were asked: "\(question)"
        Their recording lasted \(Int(duration)) seconds.
        Overall score: \(overallScore)/100

        Metrics:
        - Filler words: \(fillerCount) instances
        - Pace: \(paceScore)/10
        - Clarity: \(clarityScore)/10
        - Structure: \(structureScore)/10
        - Vocabulary Strength: \(vocabularyScore)/10

        Transcript excerpt: "\(excerpt)"

        Return ONLY valid JSON in this exact format:
        {
          "feedback": "One paragraph of specific, actionable coaching feedback."
        }

        Your feedback must:
        - Reference the actual question they were answering
        - Acknowledge one specific strength from their performance
        - Identify the most important area to improve
        - Be direct and coaching-oriented — no cheerful filler phrases like "Great job!" or "Keep it up!"
        - Be calibrated to level \(level): gentler for levels 1-4, rigorous for levels 7-10
        - Be mode-aware: \(mode.displayName) context affects what "good" looks like
        """
    }

    static func fetchFeedback(
        client: ClaudeClient,
        mode: SessionMode,
        level: Int,
        question: String,
        duration: TimeInterval,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        transcript: String
    ) async -> String? {
        let prompt = buildPrompt(
            mode: mode, level: level, question: question,
            duration: duration, overallScore: overallScore,
            fillerCount: fillerCount, paceScore: paceScore,
            clarityScore: clarityScore, structureScore: structureScore,
            vocabularyScore: vocabularyScore, transcript: transcript
        )

        do {
            return try await client.fetchFeedback(prompt: prompt)
        } catch {
            return nil
        }
    }
}
