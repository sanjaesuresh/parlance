// ParlanceTests/PersistenceDiagnosticTests.swift
import Testing
import Foundation
import SwiftData
@testable import Parlance

// MARK: - Helpers

@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

@MainActor
private func makePersistentContainer(url: URL) throws -> ModelContainer {
    let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
    let config = ModelConfiguration(url: url)
    return try ModelContainer(for: schema, configurations: [config])
}

private func makeSession(daysAgo: Double = 0, score: Int = 75) -> Session {
    let result = ScoringResult(
        metrics: ["pace": MetricScore(score: 7, tip: "Good")],
        overallScore: score,
        feedback: "Test feedback",
        bestMoment: ScoringMoment(quote: "good line", reason: "clear"),
        worstMoment: ScoringMoment(quote: "bad line", reason: "vague")
    )
    let s = Session(
        mode: .interview,
        difficultyLevel: 3,
        duration: 90,
        transcript: "Test transcript",
        fillerCount: 2,
        question: "Tell me about yourself",
        scoringResult: result,
        xpEarned: 40,
        wasDailyChallenge: false
    )
    s.date = Date(timeIntervalSinceNow: -daysAgo * 86400)
    return s
}

// MARK: - Week Calculation

@Suite("Week Calculation")
@MainActor
struct WeekCalculationTests {

    @Test("weekStart resolves to a real date in the past 7 days")
    func weekStartIsReasonable() {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        #expect(weekStart != .distantPast, "weekStart must not fall back to distantPast")
        let sevenDaysAgo = Date(timeIntervalSinceNow: -7 * 86400)
        #expect(weekStart > sevenDaysAgo, "weekStart should be within the past 7 days")
        #expect(weekStart < .now, "weekStart must be in the past")
        print("[Diagnostic] weekStart = \(weekStart)")
    }

    @Test("Session from today passes the week filter")
    func sessionFromTodayIsIncluded() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.mainContext

        let s = makeSession(daysAgo: 0)
        ctx.insert(s)
        try ctx.save()

        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        let all = try ctx.fetch(FetchDescriptor<Session>())
        let thisWeek = all.filter { $0.date >= weekStart }

        print("[Diagnostic] session.date = \(s.date), weekStart = \(weekStart), included = \(!thisWeek.isEmpty)")
        #expect(thisWeek.count == 1, "Session from today must appear in this week")
    }

    @Test("Session from 8 days ago is excluded")
    func sessionFrom8DaysAgoIsExcluded() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.mainContext

        let s = makeSession(daysAgo: 8)
        ctx.insert(s)
        try ctx.save()

        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        let all = try ctx.fetch(FetchDescriptor<Session>())
        let thisWeek = all.filter { $0.date >= weekStart }

        print("[Diagnostic] session.date = \(s.date), weekStart = \(weekStart), included = \(!thisWeek.isEmpty)")
        #expect(thisWeek.count == 0, "Session from 8 days ago must not appear in this week")
    }
}

// MARK: - Persistent Store

@Suite("Persistent Store")
@MainActor
struct PersistentStoreTests {

    @Test("Persistent store initializes without throwing")
    func persistentStoreInitializes() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storeURL = tmpDir.appendingPathComponent("test.store")
        let container = try makePersistentContainer(url: storeURL)
        // `mainContext` is non-optional — reaching this line means it exists.
        // We exercise it once to ensure SwiftData lazy-initializes without throwing.
        _ = container.mainContext
        print("[Diagnostic] Persistent container initialized at \(storeURL.path)")
    }

    @Test("Session survives in-memory save/fetch round-trip")
    func sessionSurvivesRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.mainContext

        let s = makeSession(daysAgo: 0, score: 88)
        ctx.insert(s)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Session>())
        print("[Diagnostic] Saved 1 session, fetched \(fetched.count), score = \(fetched.first?.overallScore ?? -1)")
        #expect(fetched.count == 1, "Should find the saved session")
        #expect(fetched.first?.overallScore == 88, "Score should survive round-trip")
    }

    @Test("Session persists across separate ModelContainer instances (disk)")
    func sessionPersistsAcrossContainers() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storeURL = tmpDir.appendingPathComponent("test.store")

        // Write
        let containerA = try makePersistentContainer(url: storeURL)
        let ctxA = containerA.mainContext
        ctxA.insert(makeSession(daysAgo: 0, score: 92))
        try ctxA.save()

        // Read from a new container pointing to the same file
        let containerB = try makePersistentContainer(url: storeURL)
        let ctxB = containerB.mainContext
        let fetched = try ctxB.fetch(FetchDescriptor<Session>())

        print("[Diagnostic] Cross-container fetch: \(fetched.count) sessions, score = \(fetched.first?.overallScore ?? -1)")
        #expect(fetched.count == 1, "Session must persist across container instances")
        #expect(fetched.first?.overallScore == 92, "Score must be correct after reload")
    }
}

// MARK: - PersistenceService Integration

@Suite("PersistenceService Integration")
@MainActor
struct PersistenceServiceIntegrationTests {

    @Test("saveSession then sessionsThisWeek returns it")
    func saveAndFetchThisWeek() throws {
        let service = PersistenceService.forTesting()
        service.saveSession(makeSession(daysAgo: 0, score: 80))

        let thisWeek = service.sessionsThisWeek()
        print("[Diagnostic] sessionsThisWeek count after saving today's session: \(thisWeek.count)")
        #expect(thisWeek.count == 1, "Session saved today must appear in sessionsThisWeek")
    }

    @Test("sessionsThisWeek excludes 10-day-old session")
    func oldSessionExcluded() throws {
        let service = PersistenceService.forTesting()
        service.saveSession(makeSession(daysAgo: 10, score: 60))
        service.saveSession(makeSession(daysAgo: 1, score: 80))

        let thisWeek = service.sessionsThisWeek()
        let scores = thisWeek.map(\.overallScore)
        print("[Diagnostic] sessionsThisWeek scores: \(scores)")
        #expect(!scores.contains(60), "10-day-old session must not appear in this week")
    }

    @Test("totalSessionCount matches")
    func totalCount() throws {
        let service = PersistenceService.forTesting()
        service.saveSession(makeSession(daysAgo: 0))
        service.saveSession(makeSession(daysAgo: 2))
        service.saveSession(makeSession(daysAgo: 10))

        let count = service.totalSessionCount()
        print("[Diagnostic] totalSessionCount = \(count)")
        #expect(count == 3)
    }
}
