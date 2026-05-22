import SwiftUI
import SwiftData
import CoreText

@main
struct ParlanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue

    init() {
        registerFonts()
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
                .environmentObject(authService)
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
                .task {
                    if authService.isAuthenticated {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
