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
        // Sound effects ship ON. ProfileViewModel reads with `object(forKey:) as? Bool ?? true`,
        // but SoundService.play uses `bool(forKey:)` which defaults to false — registering the
        // default here keeps both in sync so new users hear the sounds the toggle claims are on.
        UserDefaults.standard.register(defaults: ["soundEffectsEnabled": true])
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
                .onAppear {
                    applyInterfaceStyle(AppTheme(rawValue: themeRaw) ?? .system)
                }
                .onChange(of: themeRaw) { _, newValue in
                    applyInterfaceStyle(AppTheme(rawValue: newValue) ?? .system)
                }
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
        }
        .modelContainer(PersistenceService.shared.container)
    }

    // SwiftUI's `.preferredColorScheme` doesn't reliably propagate to UIKit
    // chrome (UINavigationBar toolbars, UITabBar, picker menus) at runtime,
    // so the bottom tab bar and the Settings "Done" bar would lag behind a
    // theme switch. Imperatively overriding the window style forces every
    // UIKit surface to re-resolve its dynamic colors in lockstep.
    private func applyInterfaceStyle(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .system: style = .unspecified
        case .dark: style = .dark
        case .light: style = .light
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
