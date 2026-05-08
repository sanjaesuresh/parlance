import SwiftUI

enum AppTheme: String, CaseIterable {
    case system
    case dark
    case light

    var displayName: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    static var current: AppTheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appTheme"),
                  let theme = AppTheme(rawValue: raw) else { return .system }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme")
        }
    }
}
