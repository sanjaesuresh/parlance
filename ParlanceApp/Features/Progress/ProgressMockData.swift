// Parlance/Features/Progress/ProgressMockData.swift
//
// Curated mock data for the Progress-tab visual-verification harness.
//
// Loaded only when the app is launched with `-mockProgressData` (see
// `ContentView.onAppear`). Always reachable in DEBUG builds; never wired
// into Release startup.
//
// The dataset mirrors the figures shown in `/tmp/parlance-progress-mocks`:
//   * 12 sessions across the last 30 days (4 in week 1, 8 across days 8-30)
//   * Standout session: Explanation, score 90, 1m 45s, 1 filler, 8d ago
//   * Avg score this week ≈ 82, prior week ≈ 76, lifetime ≈ 79
//   * Skill bar averages roughly match the chart heights specified in
//     `_docs/plans/2026-05-13-progress-tab-rework.md` §6.1
//
// Idempotent: any pre-existing Session and User rows in the supplied
// ModelContext are deleted before seeding, so re-launching with the flag
// produces a deterministic UI state.

#if DEBUG
import Foundation
import SwiftData

enum ProgressMockData {

    /// Seeds the SwiftData ModelContext with the curated session set used by
    /// the visual-verification harness. Idempotent: deletes any existing
    /// sessions first so re-launching with the flag produces a deterministic
    /// state. ONLY use when launched with `-mockProgressData`.
    @MainActor
    static func seed(into context: ModelContext) {
        wipeExisting(context: context)
        seedUser(context: context)
        seedSessions(context: context)
        try? context.save()
        unlockExpectedAchievements(context: context)
    }

    /// Apply the same unlock checks that `SessionCoordinator.checkAchievements`
    /// would have fired during normal play, so the seeded user has a realistic
    /// badge state on the Profile tab. Mirrors the logic in SessionCoordinator
    /// — keep in sync if that file evolves.
    @MainActor
    private static func unlockExpectedAchievements(context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard let user = users.first, !sessions.isEmpty else { return }

        // Make sure the catalog rows exist before we try to mark any of them
        // unlocked — seed runs before the persistence service's normal seed.
        let achievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: achievements.map { ($0.id, $0) })

        func unlock(_ id: String) {
            guard let row = byID[id], !row.isUnlocked else { return }
            row.isUnlocked = true
            row.unlockedDate = .now
            row.progress = row.goal
        }
        func progress(_ id: String, _ value: Int) {
            guard let row = byID[id] else { return }
            row.progress = min(value, row.goal)
            if row.progress >= row.goal { unlock(id) }
        }

        let totalSessions = sessions.count
        let totalSpoken = Int(sessions.map(\.duration).reduce(0, +))
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let avgScore = sessions.map(\.overallScore).reduce(0, +) / max(1, totalSessions)
        let hasZeroFiller = sessions.contains { $0.fillerCount == 0 && !$0.transcript.isEmpty }
        let freeModes: Set<String> = Set(SessionMode.freeModes.map(\.rawValue))
        let distinctFree = Set(sessions.map(\.modeRaw)).intersection(freeModes).count
        let interviewCount = sessions.filter { $0.modeRaw == SessionMode.interview.rawValue }.count

        if totalSessions >= 1 { unlock("first_session") }
        progress("sessions_30", totalSessions)
        progress("spoke_10h", totalSpoken)

        progress("streak_3", user.currentStreak)
        if user.currentStreak >= 7 { unlock("streak_7") }
        progress("streak_30", user.currentStreak)
        progress("streak_100", user.currentStreak)

        if bestScore >= 80  { unlock("score_80") }
        if bestScore >= 90  { unlock("score_90") }
        if bestScore >= 100 { unlock("score_100") }

        if hasZeroFiller { unlock("zero_fillers") }

        if totalSessions >= 10 {
            if avgScore >= 80 { unlock("avg_80") }
            if avgScore >= 90 { unlock("avg_90") }
        }

        progress("tour_modes", distinctFree)
        progress("interview_pro", interviewCount)

        if user.rank.level >= 5  { unlock("rank_5") }
        if user.rank.level >= 10 { unlock("master") }

        try? context.save()
    }

    // MARK: - Wipe

    @MainActor
    private static func wipeExisting(context: ModelContext) {
        if let sessions = try? context.fetch(FetchDescriptor<Session>()) {
            for s in sessions { context.delete(s) }
        }
        if let users = try? context.fetch(FetchDescriptor<User>()) {
            for u in users { context.delete(u) }
        }
    }

    // MARK: - User

    @MainActor
    private static func seedUser(context: ModelContext) {
        let joinDate = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        let user = User(
            supabaseUID: "mock-progress-user",
            displayName: "Mock User",
            username: "mockuser",
            location: nil,
            occupation: nil,
            avatarEmoji: "\u{1F399}\u{FE0F}",
            joinDate: joinDate,
            xp: 1840,
            currentStreak: 17,
            longestStreak: 21,
            lastSessionDate: .now,
            practiceLevel: 5,
            hasCompletedSetup: true
        )
        context.insert(user)
    }

    // MARK: - Sessions

    @MainActor
    private static func seedSessions(context: ModelContext) {
        for spec in mockSpecs {
            context.insert(spec.build())
        }
    }

    // MARK: - Spec

    /// Sufficient field set to build either the legacy-init or the
    /// AI-scored init flavor of `Session`. We use the legacy init plus
    /// `metricScores` / `metricTips` setters so `isAIScored` returns true
    /// (the AI-scored init demands a fully-formed `ScoringResult`, which is
    /// noisier than needed for a static mock seed).
    private struct Spec {
        let mode: SessionMode
        let daysAgo: Int
        let score: Int
        let duration: TimeInterval
        let filler: Int
        let pace: Int
        let clarity: Int
        let structure: Int
        let vocab: Int
        let question: String
        let transcript: String
        let feedback: String
        let xp: Int

        @MainActor
        func build() -> Session {
            let session = Session(
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
                bestMomentTimestamp: 0,
                bestMomentText: "",
                worstMomentTimestamp: 0,
                worstMomentText: "",
                xpEarned: xp,
                wasDailyChallenge: false
            )
            session.date = Calendar.current.date(
                byAdding: .day, value: -daysAgo, to: .now
            ) ?? .now

            // Populate AI metric data so `isAIScored` returns true and the
            // standout card's metric grid pulls the correct cells.
            session.metricScores = [
                MetricKey.fillerWords.rawValue: max(0, 10 - filler),
                MetricKey.pace.rawValue:        pace,
                MetricKey.clarity.rawValue:     clarity,
                MetricKey.structure.rawValue:   structure,
                MetricKey.vocabulary.rawValue:  vocab,
            ]
            session.metricTips = [
                MetricKey.fillerWords.rawValue: "Trim 'so' and 'like' at sentence starts.",
                MetricKey.pace.rawValue:        "Slow down on key beats; let them land.",
                MetricKey.clarity.rawValue:     "Lead with the conclusion, then the path.",
                MetricKey.structure.rawValue:   "Open with the outcome, then the steps.",
                MetricKey.vocabulary.rawValue:  "Stronger verbs beat decorated adjectives.",
            ]
            return session
        }
    }

    // MARK: - Dataset
    //
    // Distribution targets (over 12 sessions):
    //   filler avg ≈ 7.2/10  → fillerCount avg ≈ 2.8
    //   pace    avg ≈ 7.6
    //   clarity avg ≈ 8.1
    //   structure avg ≈ 6.2
    //   vocab   avg ≈ 7.8
    //
    // Week (days 0–6): 4 sessions, avg overallScore ≈ 82
    // Prior week+ (days 8–30): 8 sessions, avg ≈ 76 across that span.

    private static let mockSpecs: [Spec] = [
        // ============== Week 1 (last 7 days) ==============
        Spec(
            mode: .interview, daysAgo: 0,
            score: 84, duration: 96, filler: 2,
            pace: 8, clarity: 9, structure: 7, vocab: 8,
            question: "Tell me about a time you overcame a significant challenge.",
            transcript: "Last quarter, our launch slipped two weeks. I rebuilt the schedule, cut scope by twenty percent, and shipped on the revised date.",
            feedback: "Tight STAR opening. The result landed early, which is exactly what an interviewer wants. Trim the preamble next time.",
            xp: 48
        ),
        Spec(
            mode: .casual, daysAgo: 2,
            score: 78, duration: 82, filler: 3,
            pace: 7, clarity: 8, structure: 6, vocab: 8,
            question: "Explain what you do for work to someone who's never heard of it.",
            transcript: "I build software that helps people practice speaking. Imagine a treadmill for talking: you get on, work out, and get feedback.",
            feedback: "Great analogy. The treadmill image is memorable. Fewer fillers in the second half would keep the energy high.",
            xp: 38
        ),
        Spec(
            mode: .explanation, daysAgo: 4,
            score: 86, duration: 102, filler: 2,
            pace: 8, clarity: 9, structure: 7, vocab: 9,
            question: "Walk me through how compound interest works.",
            transcript: "Compound interest is interest earning interest. Picture a snowball rolling downhill: every layer pulls more snow than the last.",
            feedback: "Excellent snowball framing. You moved cleanly from concept to picture to implication.",
            xp: 50
        ),
        Spec(
            mode: .impromptu, daysAgo: 6,
            score: 80, duration: 74, filler: 3,
            pace: 8, clarity: 8, structure: 6, vocab: 8,
            question: "You have 60 seconds: convince someone to try a new hobby.",
            transcript: "Pick one thing you've watched but never tried. Give it three sessions. By session three you'll know if it sticks.",
            feedback: "Strong setup and a clear ask. The middle wandered. Commit to a single reason.",
            xp: 40
        ),

        // ============== Standout: day 8 ==============
        Spec(
            mode: .explanation, daysAgo: 8,
            score: 90, duration: 105, filler: 1,
            pace: 9, clarity: 9, structure: 8, vocab: 9,
            question: "Walk me through how a vaccine works.",
            transcript: "A vaccine is a rehearsal. You introduce a harmless preview of the threat so your immune system writes the play before opening night.",
            feedback: "One of your strongest sessions. The layered explanation held together from start to finish. Vocabulary was precise without becoming jargon.",
            xp: 58
        ),

        // ============== Days 9–30 (7 more sessions) ==============
        Spec(
            mode: .interview, daysAgo: 11,
            score: 72, duration: 90, filler: 5,
            pace: 7, clarity: 7, structure: 6, vocab: 7,
            question: "Why do you want to work here?",
            transcript: "Your culture maps to how I actually want to work: small teams, real ownership, and product decisions made by the people building.",
            feedback: "Solid core, but the delivery was tentative. Filler words spiked when discussing culture.",
            xp: 32
        ),
        Spec(
            mode: .casual, daysAgo: 14,
            score: 76, duration: 84, filler: 4,
            pace: 7, clarity: 8, structure: 6, vocab: 8,
            question: "What's a book you'd recommend, and why?",
            transcript: "The Making of a Manager. It reframes management as a craft you can practice instead of a personality you're born with.",
            feedback: "Specific and personal. A touch fast at the end; slow down on the closing line.",
            xp: 38
        ),
        Spec(
            mode: .impromptu, daysAgo: 17,
            score: 70, duration: 68, filler: 6,
            pace: 6, clarity: 7, structure: 5, vocab: 7,
            question: "Describe your ideal workday in under two minutes.",
            transcript: "Two deep blocks, one short check-in, one creative window. The point is protected attention, not packed calendars.",
            feedback: "Good values-first opening, but the middle repeated itself. End on the outcome, not the process.",
            xp: 30
        ),
        Spec(
            mode: .explanation, daysAgo: 20,
            score: 82, duration: 94, filler: 2,
            pace: 8, clarity: 8, structure: 7, vocab: 8,
            question: "Explain how the internet works to a 10-year-old.",
            transcript: "Think of the internet as the world's biggest post office. Every page you visit is a stack of postcards, sent and sorted in a blink.",
            feedback: "The postcard analogy carried the whole explanation. Closing line felt abrupt.",
            xp: 44
        ),
        Spec(
            mode: .interview, daysAgo: 23,
            score: 74, duration: 92, filler: 4,
            pace: 7, clarity: 7, structure: 6, vocab: 7,
            question: "Describe a situation where you had to lead under pressure.",
            transcript: "Two days before the customer demo we lost our staging environment. I split the team into rebuild and rehearsal tracks.",
            feedback: "Real stakes, but the outcome was buried. Get to the result sooner.",
            xp: 34
        ),
        Spec(
            mode: .casual, daysAgo: 26,
            score: 76, duration: 78, filler: 3,
            pace: 8, clarity: 8, structure: 6, vocab: 8,
            question: "What's something you changed your mind about recently?",
            transcript: "I used to think feedback should always be immediate. Now I think the best feedback is written, slept on, then sent.",
            feedback: "Concrete pivot. The pause-before-send insight is sticky.",
            xp: 38
        ),
        Spec(
            mode: .impromptu, daysAgo: 29,
            score: 72, duration: 70, filler: 5,
            pace: 7, clarity: 7, structure: 5, vocab: 7,
            question: "Pitch your favorite restaurant in 60 seconds.",
            transcript: "Tiny ramen counter on the corner, twelve seats, one menu item, twenty-year line cook. The broth is the whole argument.",
            feedback: "Strong picture. The list of details could collapse into one vivid image.",
            xp: 32
        ),
    ]
}
#endif
