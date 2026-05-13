import Foundation

enum PeriodFilter: String, CaseIterable, Identifiable {
    case week
    case month
    case allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "30 days"
        case .allTime: return "All time"
        }
    }

    /// Number of days included in the window. nil = unbounded.
    var dayWindow: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .allTime: return nil
        }
    }

    /// Returns the cutoff date for filtering sessions, relative to `now`.
    /// Sessions with `date >= cutoff` belong to the period. nil = no cutoff.
    func cutoff(now: Date = .now) -> Date? {
        guard let window = dayWindow else { return nil }
        return Calendar.current.date(byAdding: .day, value: -window, to: now)
    }
}
