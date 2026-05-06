// ParlanceTests/SyncServiceTests.swift
import Testing
import Foundation
@testable import Parlance

@Suite("SyncService")
struct SyncServiceTests {

    @Test("weeklyXP is sum of session XP earned this week")
    func weeklyXPSumsCurrentWeekSessions() {
        let values = [120, 200, 120]
        #expect(SyncService.sumXP(values) == 440)
    }

    @Test("sumXP returns 0 for empty array")
    func weeklyXPEmptyReturnsZero() {
        #expect(SyncService.sumXP([]) == 0)
    }

    @Test("avgScore rounds correctly")
    func avgScoreComputation() {
        #expect(SyncService.average(scores: [80, 70, 90]) == 80)
        #expect(SyncService.average(scores: [71, 72]) == 71) // integer division
        #expect(SyncService.average(scores: []) == 0)
    }
}
