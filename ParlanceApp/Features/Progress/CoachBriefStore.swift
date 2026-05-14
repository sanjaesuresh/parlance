// Parlance/Features/Progress/CoachBriefStore.swift
//
// Persists the most recent weekly coach brief in UserDefaults and gates
// when a refresh is allowed. Cadence rules (per plan §1 and §7):
//
//   - Refresh on first foreground after Monday 00:00 local time
//   - Only if >=2 sessions in the past 7 days
//   - Never within 5 days of the last successful refresh
//   - Manual pull-to-refresh allowed once per 24h (separate from the auto)
//
// Failures: keep the prior cached brief, mark the attempt timestamp so we
// don't burn the network every minute, retry on next foreground.

import Foundation
import Combine

@MainActor
final class CoachBriefStore: ObservableObject {
    @Published private(set) var latest: WeeklyBrief?
    @Published private(set) var lastAttemptAt: Date?

    private let defaults: UserDefaults
    private let calendar: Calendar

    private enum Keys {
        static let latest = "coachBrief.latest"
        static let lastAttemptAt = "coachBrief.lastAttemptAt"
        static let lastManualRefreshAt = "coachBrief.lastManualRefreshAt"
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        self.latest = Self.loadBrief(from: defaults)
        if let timestamp = defaults.object(forKey: Keys.lastAttemptAt) as? Date {
            self.lastAttemptAt = timestamp
        }
    }

    // MARK: - Cadence

    /// Auto-refresh is allowed when:
    ///   1. We have no cached brief, OR
    ///   2. The cached brief is older than 5 days AND today is past the most
    ///      recent Monday 00:00 local boundary.
    func shouldAutoRefresh(now: Date = .now) -> Bool {
        guard let latest else { return true }

        let cachedAt = latest.generatedAt
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60
        guard now.timeIntervalSince(cachedAt) >= fiveDays else { return false }

        let mondayCutoff = mostRecentMonday(before: now)
        return cachedAt < mondayCutoff
    }

    /// Manual (pull-to-refresh) is allowed once per 24h.
    func canManuallyRefresh(now: Date = .now) -> Bool {
        guard let lastManual = defaults.object(forKey: Keys.lastManualRefreshAt) as? Date else { return true }
        return now.timeIntervalSince(lastManual) >= 24 * 60 * 60
    }

    private func mostRecentMonday(before date: Date) -> Date {
        // Calendar.firstWeekday defaults are locale-dependent; pin to Monday.
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    // MARK: - Save / reset

    func save(_ brief: WeeklyBrief, manual: Bool = false, now: Date = .now) {
        latest = brief
        lastAttemptAt = now

        if let data = try? makeEncoder().encode(brief) {
            defaults.set(data, forKey: Keys.latest)
        }
        defaults.set(now, forKey: Keys.lastAttemptAt)
        if manual {
            defaults.set(now, forKey: Keys.lastManualRefreshAt)
        }
    }

    /// Called on failure so we don't retry in a tight loop. Does NOT mutate
    /// `latest` — the prior cached brief stays visible.
    func markAttempt(now: Date = .now) {
        lastAttemptAt = now
        defaults.set(now, forKey: Keys.lastAttemptAt)
    }

    func clear() {
        latest = nil
        lastAttemptAt = nil
        defaults.removeObject(forKey: Keys.latest)
        defaults.removeObject(forKey: Keys.lastAttemptAt)
        defaults.removeObject(forKey: Keys.lastManualRefreshAt)
    }

    // MARK: - Encoding helpers

    private static func loadBrief(from defaults: UserDefaults) -> WeeklyBrief? {
        guard let data = defaults.data(forKey: Keys.latest) else { return nil }
        return try? makeDecoder().decode(WeeklyBrief.self, from: data)
    }

    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
