import SwiftUI
import Combine
import SwiftData

@MainActor
final class ProgressViewModel: ObservableObject {

    func scoreHistory(from sessions: [Session]) -> [Int] {
        // sessions is sorted newest-first; take most recent 16 then reverse so chart goes oldest→newest
        Array(sessions.prefix(16).reversed().map(\.overallScore))
    }

    func weeklyActivity(from sessions: [Session]) -> [Int] {
        let calendar = Calendar.current
        var counts = Array(repeating: 0, count: 7) // Mon-Sun

        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.date)
            let index = (weekday + 5) % 7
            counts[index] += 1
        }
        return counts
    }

    struct SkillTrend {
        let name: String
        let current: Double
        let previous: Double
        var delta: Double { current - previous }
    }

    func skillTrends(currentWeek: [Session], previousWeek: [Session]) -> [SkillTrend] {
        let keys: [MetricKey] = MetricKey.universal

        return keys.compactMap { key in
            func avgScore(_ sessions: [Session]) -> Double {
                let scores: [Int] = sessions.compactMap { s in
                    if let score = s.metricScores[key.rawValue] { return score }
                    switch key {
                    case .pace:        return s.paceScore >= 0 ? s.paceScore : nil
                    case .clarity:     return s.clarityScore >= 0 ? s.clarityScore : nil
                    case .structure:   return s.structureScore >= 0 ? s.structureScore : nil
                    case .vocabulary:  return s.vocabularyScore >= 0 ? s.vocabularyScore : nil
                    case .fillerWords: return s.fillerCount >= 0 ? max(0, 10 - s.fillerCount) : nil
                    default:           return nil
                    }
                }
                guard !scores.isEmpty else { return 0 }
                return Double(scores.reduce(0, +)) / Double(scores.count)
            }

            let curr = avgScore(currentWeek)
            let prev = avgScore(previousWeek)
            guard curr > 0 || prev > 0 else { return nil }
            return SkillTrend(name: key.displayName, current: curr, previous: prev)
        }
    }

    struct ModeBreakdown {
        let mode: SessionMode
        let count: Int
        let bestScore: Int
    }

    func modeBreakdown(from sessions: [Session]) -> [ModeBreakdown] {
        SessionMode.allCases.map { mode in
            let modeSessions = sessions.filter { $0.mode == mode }
            return ModeBreakdown(
                mode: mode,
                count: modeSessions.count,
                bestScore: modeSessions.map(\.overallScore).max() ?? 0
            )
        }
    }
}
