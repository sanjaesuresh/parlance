// Parlance/Features/Progress/WeeklyBriefAggregator.swift
//
// Builds the WeeklyBriefRequest payload from a [Session] slice + the
// current User. Pure (no I/O), fully unit-testable. Lives client-side so
// the Worker stays stateless — the prompt is deterministic for a given
// payload, making golden-output fixtures trivial.
//
// See /coach/weekly-brief contract in
// cloudflare-worker/src/weeklyBrief.js and the plan at
// _docs/plans/2026-05-13-weekly-coach-brief-server.md §2.

import Foundation

// MARK: - Wire types (match Worker JSON schema exactly)

struct WeeklyBriefRequest: Codable, Equatable {
    let weekStart: String
    let isPro: Bool
    let user: UserContext
    let thisWeek: WeekStats
    let priorWeek: TimeRangeStats
    let allTime: TimeRangeStats
    let metrics: [MetricRow]
    let biggestImprovement: MetricMovement?
    let biggestRegression: MetricMovement?
    let proEmotion: ProEmotion?

    struct UserContext: Codable, Equatable {
        let currentStreak: Int
        let rankName: String
        let level: Int
    }

    struct WeekStats: Codable, Equatable {
        let sessionCount: Int
        let avgScore: Int
        let totalDurationSec: Int
        let modeDistribution: [String: Int]
        let paceWatchSessionCount: Int
        let bestSession: SessionRef
        let worstSession: SessionRef?
    }

    struct TimeRangeStats: Codable, Equatable {
        let sessionCount: Int
        let avgScore: Int
        let totalDurationSec: Int
    }

    struct SessionRef: Codable, Equatable {
        let mode: String
        let score: Int
        let question: String
        let date: String   // YYYY-MM-DD
        let aiCoachFeedback: String?
    }

    struct MetricRow: Codable, Equatable {
        let key: String    // "filler" | "pace" | "clarity" | "structure" | "vocabulary"
        let thisWeek: Double
        let priorWeek: Double
        let allTime: Double
        let deltaVsPrior: Double
        let deltaVsAllTime: Double
    }

    struct MetricMovement: Codable, Equatable {
        let key: String
        let delta: Double
    }

    struct ProEmotion: Codable, Equatable {
        let avgConfidence: Double
        let avgNervousness: Double
        let avgEnthusiasm: Double
        let dominantEmotion: String
    }
}

// MARK: - Aggregator

enum WeeklyBriefAggregator {

    /// Builds the request payload, or nil if there aren't enough sessions
    /// in the current week to bother. The Worker also enforces the >=2
    /// rule and returns 400 insufficient_data — we short-circuit here so
    /// we never burn a rate-limit bucket on a sure-rejection.
    static func build(
        sessions: [Session],
        user: User?,
        isPro: Bool,
        now: Date = .now,
        calendar: Calendar = Calendar.current
    ) -> WeeklyBriefRequest? {
        let weekStart = startOfWeek(for: now, calendar: calendar)
        let priorStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let priorEnd = weekStart

        let thisWeekSessions = sessions.filter { $0.date >= weekStart }
        let priorWeekSessions = sessions.filter { $0.date >= priorStart && $0.date < priorEnd }

        guard thisWeekSessions.count >= 2 else { return nil }

        let thisWeekStats = buildWeekStats(sessions: thisWeekSessions, calendar: calendar)
        let priorWeekStats = buildRange(sessions: priorWeekSessions)
        let allTimeStats = buildRange(sessions: sessions)

        let metricKeys: [(key: String, metricKey: MetricKey)] = [
            ("filler", .fillerWords),
            ("pace", .pace),
            ("clarity", .clarity),
            ("structure", .structure),
            ("vocabulary", .vocabulary),
        ]

        var metrics: [WeeklyBriefRequest.MetricRow] = []
        for (label, key) in metricKeys {
            let tw = metricMean(thisWeekSessions, for: key)
            let pw = metricMean(priorWeekSessions, for: key)
            let at = metricMean(sessions, for: key)
            metrics.append(.init(
                key: label,
                thisWeek: tw,
                priorWeek: pw,
                allTime: at,
                deltaVsPrior: round1(tw - pw),
                deltaVsAllTime: round1(tw - at)
            ))
        }

        let biggestImprovement = metrics.max(by: { $0.deltaVsPrior < $1.deltaVsPrior }).flatMap { row -> WeeklyBriefRequest.MetricMovement? in
            row.deltaVsPrior > 0 ? .init(key: row.key, delta: row.deltaVsPrior) : nil
        }
        let biggestRegression = metrics.min(by: { $0.deltaVsPrior < $1.deltaVsPrior }).flatMap { row -> WeeklyBriefRequest.MetricMovement? in
            row.deltaVsPrior < -0.5 ? .init(key: row.key, delta: row.deltaVsPrior) : nil
        }

        let proEmotion: WeeklyBriefRequest.ProEmotion? = isPro ? aggregateEmotion(sessions: thisWeekSessions) : nil

        let weekStartIso = ISO8601DateFormatter().string(from: weekStart)
        let userContext = WeeklyBriefRequest.UserContext(
            currentStreak: user?.currentStreak ?? 0,
            rankName: (user?.rank.name) ?? "Newcomer",
            level: user?.rank.level ?? 1
        )

        return WeeklyBriefRequest(
            weekStart: weekStartIso,
            isPro: isPro,
            user: userContext,
            thisWeek: thisWeekStats,
            priorWeek: priorWeekStats,
            allTime: allTimeStats,
            metrics: metrics,
            biggestImprovement: biggestImprovement,
            biggestRegression: biggestRegression,
            proEmotion: proEmotion
        )
    }

    // MARK: - Helpers

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func buildRange(sessions: [Session]) -> WeeklyBriefRequest.TimeRangeStats {
        let avg = sessions.isEmpty ? 0 : sessions.map(\.overallScore).reduce(0, +) / sessions.count
        let dur = Int(sessions.map(\.duration).reduce(0, +))
        return .init(sessionCount: sessions.count, avgScore: avg, totalDurationSec: dur)
    }

    private static func buildWeekStats(sessions: [Session], calendar: Calendar) -> WeeklyBriefRequest.WeekStats {
        let range = buildRange(sessions: sessions)

        var distribution: [String: Int] = [:]
        for s in sessions {
            distribution[s.mode.rawValue, default: 0] += 1
        }

        let paceWatch = sessions.reduce(0) { acc, s in acc + (wpm(for: s) > 175 ? 1 : 0) }

        let bestSession = sessions.max(by: { $0.overallScore < $1.overallScore })
            .map { Self.sessionRef(for: $0) }
            ?? WeeklyBriefRequest.SessionRef(mode: "", score: 0, question: "", date: "", aiCoachFeedback: nil)
        let worstSession = sessions.min(by: { $0.overallScore < $1.overallScore }).map { Self.sessionRef(for: $0) }

        return WeeklyBriefRequest.WeekStats(
            sessionCount: range.sessionCount,
            avgScore: range.avgScore,
            totalDurationSec: range.totalDurationSec,
            modeDistribution: distribution,
            paceWatchSessionCount: paceWatch,
            bestSession: bestSession,
            worstSession: bestSession.score == (worstSession?.score ?? -1) ? nil : worstSession
        )
    }

    private static func sessionRef(for session: Session) -> WeeklyBriefRequest.SessionRef {
        let truncated = (session.aiCoachFeedback ?? "").prefix(200)
        return .init(
            mode: session.mode.displayName,
            score: session.overallScore,
            question: session.question,
            date: dateOnly(session.date),
            aiCoachFeedback: truncated.isEmpty ? nil : String(truncated)
        )
    }

    private static func dateOnly(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return fmt.string(from: date)
    }

    /// Mean of a metric across a session list. Falls back to legacy scores
    /// and the `10 - fillerCount` rule for filler. Returns 0 when no
    /// session contributed.
    private static func metricMean(_ sessions: [Session], for key: MetricKey) -> Double {
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
        return round1(Double(scores.reduce(0, +)) / Double(scores.count))
    }

    private static func round1(_ v: Double) -> Double {
        (v * 10).rounded() / 10
    }

    private static func wpm(for session: Session) -> Int {
        guard session.duration > 0, !session.transcript.isEmpty else { return 0 }
        let words = session.transcript.split(whereSeparator: \.isWhitespace).count
        return Int((Double(words) / session.duration) * 60)
    }

    private static func aggregateEmotion(sessions: [Session]) -> WeeklyBriefRequest.ProEmotion? {
        let withEmotion = sessions.compactMap { $0.emotionResult }
        guard !withEmotion.isEmpty else { return nil }

        let n = Double(withEmotion.count)
        let confidence = withEmotion.map(\.confidenceScore).reduce(0, +) / n
        let nervousness = withEmotion.map(\.nervousnessScore).reduce(0, +) / n
        let enthusiasm = withEmotion.map(\.enthusiasmScore).reduce(0, +) / n

        // Pick the dominant emotion that appears most frequently across sessions.
        var counts: [String: Int] = [:]
        for er in withEmotion { counts[er.dominantEmotion, default: 0] += 1 }
        let dominant = counts.max(by: { $0.value < $1.value })?.key ?? "Determination"

        return .init(
            avgConfidence: round1(confidence),
            avgNervousness: round1(nervousness),
            avgEnthusiasm: round1(enthusiasm),
            dominantEmotion: dominant
        )
    }
}
