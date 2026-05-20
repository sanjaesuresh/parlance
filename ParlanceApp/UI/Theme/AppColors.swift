import SwiftUI

enum AppColors {
    // MARK: - Backgrounds & Surfaces
    static let bg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#121212")
            : UIColor(hex: "#E4DDCB")
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#1A1A1A")
            : UIColor(hex: "#F1EAD6")
    })

    static let card2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#222222")
            : UIColor(hex: "#FAF5E5")
    })

    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2A2A2A")
            : UIColor(hex: "#D5CCB4")
    })

    static let faint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2E2E2E")
            : UIColor(hex: "#FCF7E8")
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
            : UIColor(hex: "#5C5749")
    })

    static let dim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#666666")
            : UIColor(hex: "#8A8472")
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

    // MARK: - Badge tiers
    //
    // Used by the profile badge row. Bronze and silver are intentionally
    // a touch muted in dark mode so the gold tier still feels the most
    // prestigious in the row. All three share warm-to-cool sequencing.

    static let bronze = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#B07A4A")
            : UIColor(hex: "#8E5A2E")
    })

    static let silver = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#B8C0CE")
            : UIColor(hex: "#7A8597")
    })

    // (Gold tier uses the existing `gold` token — keeps the brand accent.)

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
            : UIColor(red: 0.949, green: 0.910, blue: 0.776, alpha: 1)
    })

    static let momentBestBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.102, blue: 0.078, alpha: 1)
            : UIColor(red: 0.851, green: 0.910, blue: 0.843, alpha: 1)
    })

    static let momentWorstBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.055, blue: 0.055, alpha: 1)
            : UIColor(red: 0.929, green: 0.831, blue: 0.796, alpha: 1)
    })

    static let challengeGradientStart = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.071, blue: 0.0, alpha: 1)
            : UIColor(red: 0.937, green: 0.878, blue: 0.635, alpha: 1)
    })

    static let challengeGradientEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.090, blue: 0.0, alpha: 1)
            : UIColor(red: 0.867, green: 0.780, blue: 0.424, alpha: 1)
    })

    static let challengeIconFg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.07, blue: 0.0, alpha: 1)
            : UIColor(red: 0.24, green: 0.18, blue: 0.0, alpha: 1)
    })

    static let leagueBannerStart = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.078, blue: 0.0, alpha: 1)
            : UIColor(red: 0.937, green: 0.878, blue: 0.635, alpha: 1)
    })

    static let leagueBannerEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.133, green: 0.102, blue: 0.0, alpha: 1)
            : UIColor(red: 0.867, green: 0.780, blue: 0.424, alpha: 1)
    })
}
