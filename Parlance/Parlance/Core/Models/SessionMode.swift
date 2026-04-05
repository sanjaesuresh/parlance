import SwiftUI

enum SessionMode: String, CaseIterable, Codable {
    case interview
    case pitch
    case keynote
    case casual

    var displayName: String {
        switch self {
        case .interview: "Job Interview"
        case .pitch: "Pitch / Sales"
        case .keynote: "Keynote / Talk"
        case .casual: "Daily Convo"
        }
    }

    var emoji: String {
        switch self {
        case .interview: "💼"
        case .pitch: "🚀"
        case .keynote: "🎤"
        case .casual: "💬"
        }
    }

    var accentColor: Color {
        switch self {
        case .interview: AppColors.gold
        case .pitch: Color(hex: "#E89020")
        case .keynote: AppColors.purple
        case .casual: AppColors.teal
        }
    }

    static func dailyChallengeMode(weekday: Int) -> SessionMode {
        switch weekday {
        case 2: .interview  // Monday
        case 3: .pitch      // Tuesday
        case 4: .keynote    // Wednesday
        case 5: .casual     // Thursday
        case 6: .interview  // Friday
        case 7: .pitch      // Saturday
        case 1: .keynote    // Sunday
        default: .interview
        }
    }
}
