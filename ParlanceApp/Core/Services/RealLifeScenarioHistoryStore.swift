import Foundation

struct ScenarioHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
}

final class RealLifeScenarioHistoryStore {
    nonisolated(unsafe) static let shared = RealLifeScenarioHistoryStore()

    private let defaults: UserDefaults
    private let key = "realLife.recentScenarios"
    private let cap = 5

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recent() -> [ScenarioHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([ScenarioHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var entries = recent()
        if entries.first?.text == trimmed { return }

        entries.insert(
            ScenarioHistoryEntry(id: UUID(), text: trimmed, createdAt: Date()),
            at: 0
        )
        if entries.count > cap { entries = Array(entries.prefix(cap)) }
        persist(entries)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func persist(_ entries: [ScenarioHistoryEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}
