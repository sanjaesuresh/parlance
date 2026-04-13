// Parlance/Core/Models/TimingStats.swift
import Foundation

struct TimingStats {
    let wordCount: Int
    let speechToSilenceRatio: Double    // 0-1, proportion of time spent speaking
    let longestPauseDuration: TimeInterval
    let longestPauseAfterWord: String   // word that preceded the longest pause
    let speakingRateStdDev: Double      // std dev of word count per 10s window

    static let empty = TimingStats(
        wordCount: 0,
        speechToSilenceRatio: 0,
        longestPauseDuration: 0,
        longestPauseAfterWord: "",
        speakingRateStdDev: 0
    )

    static func compute(from segments: [WordSegment], totalDuration: TimeInterval) -> TimingStats {
        guard !segments.isEmpty, totalDuration > 0 else { return .empty }

        let speechTime = segments.map(\.duration).reduce(0, +)
        let ratio = min(1.0, speechTime / totalDuration)

        var longestPause: TimeInterval = 0
        var longestPauseWord = ""
        for i in 1..<segments.count {
            let gap = segments[i].timestamp - (segments[i-1].timestamp + segments[i-1].duration)
            if gap > longestPause {
                longestPause = gap
                longestPauseWord = segments[i-1].word
            }
        }

        let windowSize: TimeInterval = 10
        var wordsPerWindow: [Double] = []
        var windowStart: TimeInterval = 0
        while windowStart < totalDuration {
            let windowEnd = windowStart + windowSize
            let count = segments.filter { $0.timestamp >= windowStart && $0.timestamp < windowEnd }.count
            wordsPerWindow.append(Double(count))
            windowStart += windowSize
        }
        let mean = wordsPerWindow.reduce(0, +) / Double(max(1, wordsPerWindow.count))
        let variance = wordsPerWindow.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(max(1, wordsPerWindow.count))

        return TimingStats(
            wordCount: segments.count,
            speechToSilenceRatio: ratio,
            longestPauseDuration: longestPause,
            longestPauseAfterWord: longestPauseWord,
            speakingRateStdDev: sqrt(variance)
        )
    }
}
