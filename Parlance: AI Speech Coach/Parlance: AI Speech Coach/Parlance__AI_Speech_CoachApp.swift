import SwiftUI
import SwiftData

@main
struct Parlance__AI_Speech_CoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
