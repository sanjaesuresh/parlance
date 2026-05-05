import SwiftUI
import SwiftData
import CoreText

@main
struct ParlanceApp: App {
    init() {
        registerFonts()
        AnalyticsService.initialize()
    }

    private func registerFonts() {
        let names = [
            "Fraunces72pt-Bold",
            "Inter-Regular", "Inter-Medium", "Inter-Bold"
        ]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SubscriptionService.shared)
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
