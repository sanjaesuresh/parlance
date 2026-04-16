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
                .environmentObject(SubscriptionService.shared)
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
