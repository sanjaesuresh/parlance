import SwiftUI

enum LeagueTier: String, CaseIterable {
    case bronze, silver, gold, platinum, diamond

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .bronze: Color(hex: "#CD7F32")
        case .silver: Color(hex: "#C0C0C0")
        case .gold: AppColors.gold
        case .platinum: Color(hex: "#E5E4E2")
        case .diamond: Color(hex: "#B9F2FF")
        }
    }

    var minXP: Int {
        switch self {
        case .bronze: 0
        case .silver: 600
        case .gold: 1500
        case .platinum: 3000
        case .diamond: 6000
        }
    }

    var xpForNextTier: Int? {
        switch self {
        case .bronze: 600
        case .silver: 1500
        case .gold: 3000
        case .platinum: 6000
        case .diamond: nil
        }
    }

    static func from(weeklyXP: Int) -> LeagueTier {
        if weeklyXP >= 6000 { return .diamond }
        if weeklyXP >= 3000 { return .platinum }
        if weeklyXP >= 1500 { return .gold }
        if weeklyXP >= 600 { return .silver }
        return .bronze
    }
}
