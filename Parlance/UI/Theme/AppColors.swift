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
}
