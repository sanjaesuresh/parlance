import SwiftUI

extension AppColors {
    static func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }
}
