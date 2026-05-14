// Aggregator unit tests for the weekly-coach-brief feature.
// Plan: _docs/plans/2026-05-13-weekly-coach-brief-server.md §8.1.

import Testing
import Foundation
@testable import Parlance

@Suite("WeeklyBriefAggregator")
struct WeeklyBriefAggregatorTests {

    // MARK: - Fixtures

    /// Fixed reference date so tests are deterministic. A Wednesday, mid-month.
    private static let now: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 13
        comps.hour = 10
        comps.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private static func ago(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    /// Convenience: build a legacy-init Session quickly.
    private static func makeSession(
        mode: SessionMode = .interview,
        daysAgo: Int,
        score: Int,
        filler: Int = 2,
        pace: Int = 8,
        clarity: Int = 8,
        structure: Int = 7,
        vocab: Int = 8,
        duration: TimeInterval = 90,
        question: String = "Mock prompt.",
        feedback: String? = nil,
        transcript: String = "Mock transcript with several words to feed wpm computation."
    ) -> Session {
        let s = Session(
            mode: mode,
            difficultyLevel: 5,
            duration: duration,
            transcript: transcript,
            overallScore: score,
            fillerCount: filler,
            paceScore: pace,
            clarityScore: clarity,
            structureScore: structure,
            vocabularyScore: vocab,
            question: question,
            aiCoachFeedback: feedback,
            xpEarned: 40,
            wasDailyChallenge: false
        )
        s.date = ago(daysAgo)
        return s
    }

    // MARK: - Tests

    @Test("returns nil when this week has < 2 sessions")
    func returnsNilOnInsufficientData() {
        let only = [Self.makeSession(daysAgo: 1, score: 80)]
        let payload = WeeklyBriefAggregator.build(
            sessions: only,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        )
        #expect(payload == nil)
    }

    @Test("counts this-week vs prior-week sessions using Monday-anchored windows")
    func countsSessionsByWindow() {
        // 'now' is Wed May 13 2026. Monday May 11 is the start-of-week.
        let sessions: [Session] = [
            Self.makeSession(daysAgo: 0, score: 80),   // Wed this week
            Self.makeSession(daysAgo: 2, score: 85),   // Mon this week
            Self.makeSession(daysAgo: 4, score: 75),   // Sat prior week
            Self.makeSession(daysAgo: 8, score: 70),   // Tue prior week
            Self.makeSession(daysAgo: 9, score: 72),   // Mon prior week
            Self.makeSession(daysAgo: 16, score: 60),  // older still — all-time only
        ]
        let payload = WeeklyBriefAggregator.build(
            sessions: sessions,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        )

        let p = try! #require(payload)
        #expect(p.thisWeek.sessionCount == 2)
        #expect(p.priorWeek.sessionCount == 3)
        #expect(p.allTime.sessionCount == 6)
    }

    @Test("avgScore is integer mean of the window")
    func avgScoreIsRoundedMean() {
        let sessions = [
            Self.makeSession(daysAgo: 0, score: 80),
            Self.makeSession(daysAgo: 1, score: 85),
            Self.makeSession(daysAgo: 2, score: 75),
        ]
        let payload = WeeklyBriefAggregator.build(
            sessions: sessions,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        )
        let p = try! #require(payload)
        #expect(p.thisWeek.avgScore == 80)
    }

    @Test("metric deltas compare this week vs prior week vs all-time")
    func metricDeltas() {
        let thisWeek = [
            Self.makeSession(daysAgo: 0, score: 80, filler: 2, pace: 9),
            Self.makeSession(daysAgo: 1, score: 85, filler: 1, pace: 9),
        ]
        let priorWeek = [
            Self.makeSession(daysAgo: 8, score: 70, filler: 4, pace: 7),
            Self.makeSession(daysAgo: 9, score: 72, filler: 5, pace: 7),
        ]

        let payload = WeeklyBriefAggregator.build(
            sessions: thisWeek + priorWeek,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        )
        let p = try! #require(payload)

        let filler = try! #require(p.metrics.first(where: { $0.key == "filler" }))
        // this-week filler "score" = 10 - filler count, averaged
        // ((10-2) + (10-1)) / 2 = 8.5
        // prior-week filler "score" = ((10-4) + (10-5)) / 2 = 5.5
        #expect(filler.thisWeek == 8.5)
        #expect(filler.priorWeek == 5.5)
        #expect(filler.deltaVsPrior == 3.0)

        let pace = try! #require(p.metrics.first(where: { $0.key == "pace" }))
        #expect(pace.thisWeek == 9.0)
        #expect(pace.priorWeek == 7.0)
        #expect(pace.deltaVsPrior == 2.0)
    }

    @Test("biggestImprovement names the best-improving metric")
    func biggestImprovementIdentified() {
        let thisWeek = [
            Self.makeSession(daysAgo: 0, score: 80, filler: 1, pace: 7, clarity: 8, structure: 6, vocab: 8),
            Self.makeSession(daysAgo: 1, score: 85, filler: 1, pace: 7, clarity: 8, structure: 6, vocab: 8),
        ]
        let priorWeek = [
            Self.makeSession(daysAgo: 8, score: 70, filler: 5, pace: 7, clarity: 8, structure: 6, vocab: 8),
            Self.makeSession(daysAgo: 9, score: 72, filler: 5, pace: 7, clarity: 8, structure: 6, vocab: 8),
        ]
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: thisWeek + priorWeek,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))

        let imp = try! #require(payload.biggestImprovement)
        #expect(imp.key == "filler")
        #expect(imp.delta == 4.0)
    }

    @Test("biggestRegression only flags drops > 0.5")
    func biggestRegressionThreshold() {
        // Trivial dip (-0.2) should NOT flag a regression.
        let thisWeek = [
            Self.makeSession(daysAgo: 0, score: 80, pace: 8),
            Self.makeSession(daysAgo: 1, score: 80, pace: 8),
        ]
        let priorWeek = [
            Self.makeSession(daysAgo: 8, score: 78, pace: 8),
            Self.makeSession(daysAgo: 9, score: 78, pace: 8),
        ]
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: thisWeek + priorWeek,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))
        #expect(payload.biggestRegression == nil)
    }

    @Test("modeDistribution counts sessions per mode in the current week")
    func modeDistributionCounts() {
        let sessions = [
            Self.makeSession(mode: .interview,   daysAgo: 0, score: 80),
            Self.makeSession(mode: .interview,   daysAgo: 1, score: 82),
            Self.makeSession(mode: .explanation, daysAgo: 2, score: 90),
            Self.makeSession(mode: .casual,      daysAgo: 9, score: 70), // prior week — excluded
        ]
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: sessions,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))
        #expect(payload.thisWeek.modeDistribution[SessionMode.interview.rawValue] == 2)
        #expect(payload.thisWeek.modeDistribution[SessionMode.explanation.rawValue] == 1)
        #expect(payload.thisWeek.modeDistribution[SessionMode.casual.rawValue] == nil)
    }

    @Test("bestSession is the highest scoring session this week")
    func bestSessionPicked() {
        let sessions = [
            Self.makeSession(daysAgo: 0, score: 70, question: "low"),
            Self.makeSession(daysAgo: 1, score: 92, question: "best"),
            Self.makeSession(daysAgo: 2, score: 80, question: "mid"),
        ]
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: sessions,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))
        #expect(payload.thisWeek.bestSession.score == 92)
        #expect(payload.thisWeek.bestSession.question == "best")
    }

    @Test("proEmotion is nil for free-tier users even when emotion data exists")
    func proEmotionGatedByPro() {
        let sessions = [
            Self.makeSession(daysAgo: 0, score: 80),
            Self.makeSession(daysAgo: 1, score: 82),
        ]
        let free = try! #require(WeeklyBriefAggregator.build(
            sessions: sessions, user: nil, isPro: false,
            now: Self.now, calendar: Self.calendar
        ))
        #expect(free.proEmotion == nil)
    }

    @Test("paceWatchSessionCount counts sessions over 175 wpm")
    func paceWatchDetection() {
        // wpm = (word_count / duration_sec) * 60. With duration=10s, 30 words → 180 wpm.
        let fast = Self.makeSession(
            daysAgo: 0, score: 80,
            duration: 10,
            transcript: String(repeating: "word ", count: 31)
        )
        let normal = Self.makeSession(
            daysAgo: 1, score: 82,
            duration: 60,
            transcript: String(repeating: "word ", count: 100) // 100 wpm
        )
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: [fast, normal],
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))
        #expect(payload.thisWeek.paceWatchSessionCount == 1)
    }

    @Test("worstSession is omitted when there's only one session this week")
    func worstSessionOmittedWhenOnly() {
        let sessions = [
            Self.makeSession(daysAgo: 0, score: 80),
            Self.makeSession(daysAgo: 1, score: 80),
        ]
        let payload = try! #require(WeeklyBriefAggregator.build(
            sessions: sessions,
            user: nil,
            isPro: false,
            now: Self.now,
            calendar: Self.calendar
        ))
        // Best == Worst when scores tie → we collapse, leaving worst nil.
        #expect(payload.thisWeek.worstSession == nil)
    }
}
