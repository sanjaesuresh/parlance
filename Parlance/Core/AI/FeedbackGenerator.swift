// Parlance/Core/AI/FeedbackGenerator.swift
import Foundation

enum FeedbackGenerator {

    static func buildPrompt(
        mode: SessionMode,
        level: Int,
        question: String,
        transcript: String,
        timingStats: TimingStats,
        audioFeatures: AudioFeatures,
        emotionResult: EmotionResult? = nil
    ) -> String {
        let levelName = DifficultyLevel.name(for: level)
        let metrics = MetricKey.metrics(for: mode)
        let levelTone: String
        switch level {
        case 1...4: levelTone = "be constructive — acknowledge effort and point to one clear improvement"
        case 5...6: levelTone = "be direct and specific — name what worked and what to fix"
        default:    levelTone = "be rigorous — hold them to a high standard, be exacting"
        }

        let metricList = metrics.map {
            "- \($0.rawValue) (\($0.displayName)): \($0.metricDescription)"
        }.joined(separator: "\n")

        let metricsJsonTemplate = metrics.map {
            "    \"\($0.rawValue)\": { \"score\": <0-10 int>, \"tip\": \"<one specific actionable sentence>\" }"
        }.joined(separator: ",\n")

        let transcriptSection = transcript.isEmpty
            ? "(No transcript available — user did not speak or speech recognition failed)"
            : "\"\(transcript)\""

        let emotionSection: String
        if let emotion = emotionResult {
            let arcStr: String
            if emotion.emotionArc.isEmpty {
                arcStr = "N/A"
            } else {
                let first = String(format: "%.0f%%", (emotion.emotionArc.first ?? 0) * 100)
                let last = String(format: "%.0f%%", (emotion.emotionArc.last ?? 0) * 100)
                arcStr = "\(first) → \(last)"
            }
            emotionSection = """

            Vocal emotion analysis (Hume AI — use this in place of pitch-based delivery inference):
            - Dominant emotion: \(emotion.dominantEmotion) (\(String(format: "%.0f%%", emotion.dominantScore * 100)))
            - Confidence signal: \(String(format: "%.0f%%", emotion.confidenceScore * 100))
            - Nervousness: \(String(format: "%.0f%%", emotion.nervousnessScore * 100))
            - Enthusiasm/Excitement: \(String(format: "%.0f%%", emotion.enthusiasmScore * 100))
            - Confidence arc (start → end): \(arcStr)
            """
        } else {
            emotionSection = ""
        }

        return """
        You are a direct, no-nonsense speech coach evaluating a \(mode.displayName) session.
        Level: \(level) (\(levelName))
        Tone for this level: \(levelTone)

        Question asked:
        "\(question)"

        Transcript:
        \(transcriptSection)

        Session data:
        - Word count: \(timingStats.wordCount)
        - Speech-to-silence ratio: \(Int(timingStats.speechToSilenceRatio * 100))% (time actually speaking)
        - Longest pause: \(String(format: "%.1f", timingStats.longestPauseDuration))s (after "\(timingStats.longestPauseAfterWord)")
        - Speaking rate variation: \(String(format: "%.1f", timingStats.speakingRateStdDev)) words/10s std dev (higher = more varied pace)

        Audio delivery:
        - Pitch mean: \(String(format: "%.0f", audioFeatures.pitchMeanHz))Hz, std dev: \(String(format: "%.0f", audioFeatures.pitchStdDevHz))Hz (higher std dev = more dynamic, less monotone)
        - Energy mean RMS: \(String(format: "%.3f", audioFeatures.energyMeanRMS)), std dev: \(String(format: "%.3f", audioFeatures.energyStdDevRMS)) (higher std dev = more energy variation)\(emotionSection)

        Score these metrics for this \(mode.displayName) session:
        \(metricList)

        Return ONLY valid JSON — no markdown, no extra text, no code fences:
        {
          "metrics": {
        \(metricsJsonTemplate)
          },
          "overallScore": <0-100 int, your holistic judgment — NOT an average>,
          "feedback": "<one paragraph, direct coaching: reference the question, name one strength and the most important thing to fix>",
          "bestMoment": { "quote": "<exact phrase from transcript, or empty string if no transcript>", "reason": "<why it worked>" },
          "worstMoment": { "quote": "<exact phrase from transcript, or empty string if no transcript>", "reason": "<what to fix>" }
        }

        Rules:
        - overallScore is YOUR judgment of overall quality, not a formula
        - If Hume emotion data is present, use it as the primary signal for deliveryConfidence scoring
        - A high pitch std dev means dynamic delivery — reward it when no Hume data is available
        - Tips must reference what they actually said, not generic advice
        - If transcript is empty or fewer than 10 words, score all metrics 1-2 and explain in feedback
        """
    }

    static func fetchScoring(
        client: ClaudeClient,
        mode: SessionMode,
        level: Int,
        question: String,
        transcript: String,
        timingStats: TimingStats,
        audioFeatures: AudioFeatures,
        emotionResult: EmotionResult? = nil
    ) async throws -> ScoringResult {
        let prompt = buildPrompt(
            mode: mode, level: level, question: question,
            transcript: transcript, timingStats: timingStats,
            audioFeatures: audioFeatures, emotionResult: emotionResult
        )
        return try await client.fetchScoring(prompt: prompt)
    }
}
