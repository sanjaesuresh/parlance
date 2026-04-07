import SwiftUI
import SwiftData

@main
struct ParlanceApp: App {
    init() {
        AnalyticsService.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
