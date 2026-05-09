import SwiftUI
import Combine

@MainActor
final class SessionWeekCache: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var hasAnySession: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        sessions = PersistenceService.shared.sessionsThisWeek()
        hasAnySession = PersistenceService.shared.totalSessionCount() > 0
    }
}
