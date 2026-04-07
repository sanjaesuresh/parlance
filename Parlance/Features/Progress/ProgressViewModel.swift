import SwiftUI
import SwiftData
import Combine

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
        func avg(_ sessions: [Session], _ keyPath: KeyPath<Session, Int>) -> Double {
            guard !sessions.isEmpty else { return 0 }
            let valid = sessions.filter { $0[keyPath: keyPath] >= 0 }
            guard !valid.isEmpty else { return 0 }
            return Double(valid.map { $0[keyPath: keyPath] }.reduce(0, +)) / Double(valid.count)
        }

        return [
            SkillTrend(name: "Filler Words", current: avg(currentWeek, \.fillerCount), previous: avg(previousWeek, \.fillerCount)),
            SkillTrend(name: "Pace", current: avg(currentWeek, \.paceScore), previous: avg(previousWeek, \.paceScore)),
            SkillTrend(name: "Clarity", current: avg(currentWeek, \.clarityScore), previous: avg(previousWeek, \.clarityScore)),
            SkillTrend(name: "Structure", current: avg(currentWeek, \.structureScore), previous: avg(previousWeek, \.structureScore)),
            SkillTrend(name: "Vocabulary", current: avg(currentWeek, \.vocabularyScore), previous: avg(previousWeek, \.vocabularyScore))
        ]
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
