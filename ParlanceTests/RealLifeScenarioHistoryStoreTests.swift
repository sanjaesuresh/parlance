import Testing
import Foundation
@testable import Parlance

@Suite("RealLifeScenarioHistoryStore")
struct RealLifeScenarioHistoryStoreTests {

    /// Each test gets a fresh in-memory UserDefaults suite so they don't
    /// step on each other.
    private static func freshStore() -> RealLifeScenarioHistoryStore {
        let suiteName = "test.realLife.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return RealLifeScenarioHistoryStore(defaults: defaults)
    }

    @Test("empty store returns empty list")
    func empty() {
        let store = Self.freshStore()
        #expect(store.recent().isEmpty)
    }

    @Test("record then recent returns the entry")
    func recordOne() {
        let store = Self.freshStore()
        store.record("ask for a raise")
        let recent = store.recent()
        #expect(recent.count == 1)
        #expect(recent[0].text == "ask for a raise")
    }

    @Test("most recent appears first")
    func mostRecentFirst() {
        let store = Self.freshStore()
        store.record("one")
        store.record("two")
        store.record("three")
        let recent = store.recent()
        #expect(recent.map(\.text) == ["three", "two", "one"])
    }

    @Test("capped at 5 entries — oldest is evicted")
    func cappedAtFive() {
        let store = Self.freshStore()
        for i in 1...7 { store.record("scenario \(i)") }
        let recent = store.recent()
        #expect(recent.count == 5)
        #expect(recent.map(\.text) == ["scenario 7", "scenario 6", "scenario 5", "scenario 4", "scenario 3"])
    }

    @Test("recording identical text consecutively does not duplicate")
    func dedupeConsecutive() {
        let store = Self.freshStore()
        store.record("same")
        store.record("same")
        #expect(store.recent().count == 1)
    }

    @Test("whitespace-only scenarios are ignored")
    func whitespaceIgnored() {
        let store = Self.freshStore()
        store.record("   \n  ")
        #expect(store.recent().isEmpty)
    }

    @Test("clear empties the store")
    func clear() {
        let store = Self.freshStore()
        store.record("scenario")
        store.clear()
        #expect(store.recent().isEmpty)
    }
}
