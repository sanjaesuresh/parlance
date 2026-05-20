import SwiftUI

enum AppColors {
    // MARK: - Backgrounds & Surfaces
    static let bg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#141312")
            : UIColor(hex: "#E4DDCB")
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#1B1A17")
            : UIColor(hex: "#FBF8F2")
    })

    static let card2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#232117")
            : UIColor(hex: "#FAF5E5")
    })

    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2B281D")
            : UIColor(hex: "#D5CCB4")
    })

    static let faint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#2F2C20")
            : UIColor(hex: "#FCF7E8")
    })

    // MARK: - Text
    static let text = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#F5F2EA")
            : UIColor(hex: "#1A1814")
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
    static let goldDeep = Color(hex: "#A57E1B")

    // Softer red used for inline negative emphasis in the coach brief.
    static let redSoft = Color(hex: "#E89180")

    // MARK: - Badge tiers
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

    // Foreground for content placed on AppColors.gold (icons, glyphs, text).
    static let onGold = Color(hex: "#1A1A1A")

    // Foreground for content placed on saturated accent backgrounds (red, teal, purple).
    // Fixed warm near-white so contrast holds in both light and dark mode.
    static let onAccent = Color(hex: "#F5F2EA")

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

    // MARK: - Semantic State Tokens
    static let success = Color(hex: "#7FBF96")
    static let warning = Color(hex: "#D9A656")
    static let error = Color(hex: "#E05A4E")
    static let info = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#3BB5A0")
            : UIColor(hex: "#2E9E8B")
    })
    static let focused = Color(hex: "#E8A838").opacity(0.4)
    static let disabled = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#666666")
            : UIColor(hex: "#8A8472")
    })
    static let selected = Color(hex: "#E8A838").opacity(0.15)
    static let pressed = Color(hex: "#E8A838").opacity(0.25)

    // MARK: - Semantic One-Off Colors
    /// Subtle warm tint used by historical / sample coach surfaces.
    /// The live Results coach card is matte (AppColors.card) by design.
    static let aiCoachBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.071, blue: 0.055, alpha: 1)
            : UIColor(red: 0.949, green: 0.910, blue: 0.776, alpha: 1)
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

    // MARK: - Difficulty Ramp
    /// Gold → red ramp across 5 bands. Band 1 = starter, band 9 = expert.
    /// Same hue family as the rest of the warm palette; never reach into raw blues or greens.
    static func difficultyRamp(band: Int) -> Color {
        switch band {
        case 1: gold
        case 3: Color(hex: "#E89438")
        case 5: Color(hex: "#E87538")
        case 7: Color(hex: "#E55A4A")
        default: red
        }
    }
}
