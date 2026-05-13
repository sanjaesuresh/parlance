import SwiftUI

enum AppColors {
    // MARK: - Backgrounds & Surfaces
    static let bg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#121212")
            : UIColor(hex: "#F5F3EF")
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#1A1A1A")
            : UIColor(hex: "#FFFFFF")
    })

    static let card2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#222222")
            : UIColor(hex: "#F0EDE8")
    })

    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2A2A2A")
            : UIColor(hex: "#E0DDD8")
    })

    static let faint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2E2E2E")
            : UIColor(hex: "#EEEBE6")
    })

    // MARK: - Text
    static let text = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .white
            : UIColor(hex: "#1A1A1A")
    })

    static let sub = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#999999")
            : UIColor(hex: "#666666")
    })

    static let dim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#666666")
            : UIColor(hex: "#999999")
    })

    // MARK: - Accents
    static let gold = Color(hex: "#E8A838")
    static let red = Color(hex: "#E05A4E")

    // Deeper gold for the bottom of the trend-chart bar gradient.
    // Approximates oklch(0.62 0.13 80) from the Progress-tab mockup.
    static let goldDeep = Color(hex: "#A57E1B")

    // Softer red used for inline negative emphasis in the coach brief.
    // Approximates oklch(0.78 0.10 28) — lighter than the alarm/danger red.
    static let redSoft = Color(hex: "#E89180")

    // Foreground for content placed on AppColors.gold (icons, glyphs, text).
    // Gold is the same in light and dark mode, so this is intentionally a fixed
    // near-black for contrast in both schemes.
    static let onGold = Color(hex: "#1A1A1A")

    static let purple = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#7B68EE")
            : UIColor(hex: "#6A58DD")
    })

    static let teal = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#3BB5A0")
            : UIColor(hex: "#2E9E8B")
    })

    // MARK: - Semantic One-Off Colors
    static let aiCoachBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.071, blue: 0.055, alpha: 1)
            : UIColor(red: 0.97, green: 0.95, blue: 0.93, alpha: 1)
    })

    static let momentBestBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.102, blue: 0.078, alpha: 1)
            : UIColor(red: 0.93, green: 0.96, blue: 0.945, alpha: 1)
    })

    static let momentWorstBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.055, blue: 0.055, alpha: 1)
            : UIColor(red: 0.96, green: 0.93, blue: 0.93, alpha: 1)
    })

    static let challengeGradientStart = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.071, blue: 0.0, alpha: 1)
            : UIColor(red: 0.96, green: 0.93, blue: 0.84, alpha: 1)
    })

    static let challengeGradientEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.090, blue: 0.0, alpha: 1)
            : UIColor(red: 0.93, green: 0.89, blue: 0.75, alpha: 1)
    })

    static let challengeIconFg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.07, blue: 0.0, alpha: 1)
            : UIColor(red: 0.24, green: 0.18, blue: 0.0, alpha: 1)
    })

    static let leagueBannerStart = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.078, blue: 0.0, alpha: 1)
            : UIColor(red: 0.96, green: 0.93, blue: 0.84, alpha: 1)
    })

    static let leagueBannerEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.133, green: 0.102, blue: 0.0, alpha: 1)
            : UIColor(red: 0.93, green: 0.89, blue: 0.75, alpha: 1)
    })
}
