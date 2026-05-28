import Foundation

/// Tracks weekly-rank-among-friends snapshots locally so we can compute a 24h delta
/// without backend changes. Snapshots are coalesced (≤30 min apart replace each other)
/// and pruned to a 7-day window to keep storage tiny.
@MainActor
final class FriendsRankHistoryService {
    static let shared = FriendsRankHistoryService()

    private let defaults = UserDefaults.standard
    private let storageKey = "parlance.friendsRankHistory.v1"
    private let maxAge: TimeInterval = 60 * 60 * 24 * 7
    private let lookback: TimeInterval = 60 * 60 * 24
    private let coalesceWindow: TimeInterval = 60 * 30

    private struct Snapshot: Codable {
        let timestamp: Date
        let ranks: [String: Int]
    }

    private var snapshots: [Snapshot] {
        get {
            guard let data = defaults.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([Snapshot].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: storageKey)
        }
    }

    /// Persist the current ranking. The most recent snapshot within `coalesceWindow`
    /// is replaced rather than appended, so frequent fetches don't bloat storage.
    func record(rankings: [(userId: String, rank: Int)]) {
        guard !rankings.isEmpty else { return }
        let map = Dictionary(rankings.map { ($0.userId, $0.rank) }, uniquingKeysWith: { a, _ in a })
        var current = snapshots
        let now = Date()
        if let last = current.last, now.timeIntervalSince(last.timestamp) < coalesceWindow {
            current[current.count - 1] = Snapshot(timestamp: now, ranks: map)
        } else {
            current.append(Snapshot(timestamp: now, ranks: map))
        }
        current.removeAll { now.timeIntervalSince($0.timestamp) > maxAge }
        snapshots = current
    }

    /// Returns the latest snapshot that is at least `lookback` old, or nil if none exists yet.
    private func snapshot24hAgo() -> Snapshot? {
        let cutoff = Date().addingTimeInterval(-lookback)
        return snapshots
            .filter { $0.timestamp <= cutoff }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Positive = moved up (better rank now). Negative = moved down. Nil = no history yet.
    func delta(userId: String, currentRank: Int) -> Int? {
        guard let prev = snapshot24hAgo()?.ranks[userId] else { return nil }
        return prev - currentRank
    }
}
