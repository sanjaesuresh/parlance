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
        SessionMode.allCases.filter { $0 != .realLife }.map { mode in
            let modeSessions = sessions.filter { $0.mode == mode }
            return ModeBreakdown(
                mode: mode,
                count: modeSessions.count,
                bestScore: modeSessions.map(\.overallScore).max() ?? 0
            )
        }
    }

    // MARK: - Period-scoped methods (Progress tab rework, plan 2026-05-13)

    struct PeriodAggregate {
        let avgScore: Int
        let avgScoreDelta: Int?       // vs prior window; nil on allTime
        let sessionCount: Int
        let sessionCountDelta: Int?
        let totalDuration: TimeInterval
        let totalDurationDelta: TimeInterval?
    }

    struct SkillTrendItem: Identifiable {
        let key: MetricKey
        let label: String
        let currentValue: Double       // 0–10
        let deltaVsAllTime: Double?    // nil on allTime
        var id: String { key.rawValue }
    }

    struct SkillCardModel: Identifiable {
        let key: MetricKey
        let displayName: String
        let value: Double
        let delta: Double?
        let note: String
        let coachTip: String
        var id: String { key.rawValue }
    }

    struct AllTimeStats {
        let sessionCount: Int
        let avgScore: Int
        let bestScore: Int
        let totalDuration: TimeInterval
        let totalXP: Int
        let longestStreak: Int
        let joinDate: Date?
    }

    struct CoachBrief {
        let body: String
        let signature: String?
        let positiveHighlights: [String]
        let negativeHighlights: [String]
    }

    /// Filter sessions to the given period window.
    func sessions(_ all: [Session], in period: PeriodFilter, now: Date = .now) -> [Session] {
        guard let cutoff = period.cutoff(now: now) else { return all }
        return all.filter { $0.date >= cutoff }
    }

    /// Sessions in the *prior* window of the same length (for delta computation).
    /// For `.allTime`, returns an empty array (no prior).
    private func priorSessions(_ all: [Session], for period: PeriodFilter, now: Date = .now) -> [Session] {
        guard let window = period.dayWindow else { return [] }
        let cal = Calendar.current
        let currentCutoff = cal.date(byAdding: .day, value: -window, to: now) ?? now
        let priorCutoff = cal.date(byAdding: .day, value: -window * 2, to: now) ?? now
        return all.filter { $0.date >= priorCutoff && $0.date < currentCutoff }
    }

    func aggregate(_ all: [Session], for period: PeriodFilter, now: Date = .now) -> PeriodAggregate {
        let current = sessions(all, in: period, now: now)
        let prior = priorSessions(all, for: period, now: now)

        let avg = current.isEmpty ? 0 : current.map(\.overallScore).reduce(0, +) / current.count
        let priorAvg = prior.isEmpty ? 0 : prior.map(\.overallScore).reduce(0, +) / prior.count
        let avgDelta: Int? = period == .allTime ? nil : (current.isEmpty || prior.isEmpty ? nil : avg - priorAvg)

        let countDelta: Int? = period == .allTime ? nil : current.count - prior.count

        let dur = current.map(\.duration).reduce(0, +)
        let priorDur = prior.map(\.duration).reduce(0, +)
        let durDelta: TimeInterval? = period == .allTime ? nil : dur - priorDur

        return PeriodAggregate(
            avgScore: avg,
            avgScoreDelta: avgDelta,
            sessionCount: current.count,
            sessionCountDelta: countDelta,
            totalDuration: dur,
            totalDurationDelta: durDelta
        )
    }

    /// Mean of a metric across a session list. Falls back to legacy scores and the
    /// `10 - fillerCount` rule for filler. Returns nil when no session contributed.
    private func metricMean(_ sessions: [Session], for key: MetricKey) -> Double? {
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
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// 5-skill trend chart data: filler, pace, clarity, structure, vocabulary.
    /// `deltaVsAllTime` is nil when period == .allTime.
    func skillTrends(_ all: [Session], for period: PeriodFilter, now: Date = .now) -> [SkillTrendItem] {
        let currentSessions = sessions(all, in: period, now: now)
        let universal: [MetricKey] = [.fillerWords, .pace, .clarity, .structure, .vocabulary]

        return universal.map { key in
            let current = metricMean(currentSessions, for: key) ?? 0
            let allTime = metricMean(all, for: key) ?? 0
            let delta: Double? = period == .allTime ? nil : current - allTime
            return SkillTrendItem(
                key: key,
                label: shortLabel(for: key),
                currentValue: current,
                deltaVsAllTime: delta
            )
        }
    }

    private func shortLabel(for key: MetricKey) -> String {
        switch key {
        case .fillerWords: return "Filler"
        case .vocabulary:  return "Vocab"
        default:           return key.displayName
        }
    }

    /// Top 3 skill cards: largest absolute delta vs all-time (improvement first, then
    /// regression). On `.allTime`, falls back to the three lowest-scoring metrics.
    func skillCards(_ all: [Session], for period: PeriodFilter, now: Date = .now) -> [SkillCardModel] {
        let trends = skillTrends(all, for: period, now: now)

        let ordered: [SkillTrendItem]
        if period == .allTime {
            ordered = trends.sorted { $0.currentValue < $1.currentValue }
        } else {
            ordered = trends.sorted { abs($0.deltaVsAllTime ?? 0) > abs($1.deltaVsAllTime ?? 0) }
        }

        return ordered.prefix(3).map { trend in
            SkillCardModel(
                key: trend.key,
                displayName: trend.key.displayName,
                value: trend.currentValue,
                delta: trend.deltaVsAllTime,
                note: cardNote(for: trend, period: period),
                coachTip: cardTip(for: trend, period: period)
            )
        }
    }

    private func cardNote(for trend: SkillTrendItem, period: PeriodFilter) -> String {
        if period == .allTime {
            return "\(trend.label) — your lifetime average."
        }
        guard let delta = trend.deltaVsAllTime else { return "" }
        if delta > 0.5 {
            return "Biggest improvement this \(period == .week ? "week" : "period")."
        } else if delta < -0.5 {
            return "Slipped vs your all-time average."
        } else {
            return "Holding steady vs all-time."
        }
    }

    private func cardTip(for trend: SkillTrendItem, period: PeriodFilter) -> String {
        // Placeholder copy — real tips come from the per-session metricTips or a
        // server-generated brief. Static fallback so the UI always has content.
        switch trend.key {
        case .fillerWords:
            return "When stakes climb, fillers cluster around transitions. Replace 'so' and 'and like' with a one-beat pause — it reads more confident, not less."
        case .pace:
            return "Pace creeps up under pressure. A two-second pause before answering buys composure without dead air."
        case .clarity:
            return "Lead with the conclusion, then the reasoning. Listeners stay engaged when they know where you're going."
        case .structure:
            return "In your last few sessions you saved the outcome for the end. Open with the result, then the path that got you there."
        case .vocabulary:
            return "Strong verbs carry more than adjectives. 'I led' over 'I was responsible for'."
        default:
            return ""
        }
    }

    /// Best session in the period — by overallScore. nil on empty window.
    func standout(_ all: [Session], in period: PeriodFilter, now: Date = .now) -> Session? {
        sessions(all, in: period, now: now).max(by: { $0.overallScore < $1.overallScore })
    }

    /// Lifetime aggregates for the All-time card.
    func allTimeStats(_ all: [Session], user: User?) -> AllTimeStats {
        let count = all.count
        let avg = count == 0 ? 0 : all.map(\.overallScore).reduce(0, +) / count
        let best = all.map(\.overallScore).max() ?? 0
        let dur = all.map(\.duration).reduce(0, +)
        let xp = all.map(\.xpEarned).reduce(0, +)
        return AllTimeStats(
            sessionCount: count,
            avgScore: avg,
            bestScore: best,
            totalDuration: dur,
            totalXP: xp,
            longestStreak: user?.longestStreak ?? 0,
            joinDate: user?.joinDate
        )
    }

    /// Stub brief — real briefs come from the weekly-coach-brief Worker (plan 2).
    /// Returns a deterministic locally-generated fallback when no server brief
    /// is cached yet. The UI hides this section entirely if fewer than 2 sessions
    /// in the window — that check lives in the View.
    func coachBrief(for period: PeriodFilter, aggregate: PeriodAggregate) -> CoachBrief? {
        guard aggregate.sessionCount >= 2 else { return nil }
        let count = aggregate.sessionCount
        let trend: String
        if let delta = aggregate.avgScoreDelta {
            if delta > 0 { trend = "up \(delta) from last \(period == .week ? "week" : "period")" }
            else if delta < 0 { trend = "down \(abs(delta)) from last \(period == .week ? "week" : "period")" }
            else { trend = "holding steady" }
        } else {
            trend = "across your sessions"
        }
        let body = "You completed \(count) sessions with an average score of \(aggregate.avgScore), \(trend). Keep stacking consistency."
        return CoachBrief(body: body, signature: nil, positiveHighlights: [], negativeHighlights: [])
    }
}
