import SwiftUI
import Combine

@MainActor
final class SessionWeekCache: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    init() {
        refresh()
    }

    func refresh() {
        sessions = PersistenceService.shared.sessionsThisWeek()
    }
}
