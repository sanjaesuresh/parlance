import SwiftUI

struct PillBadge: View {
    let text: String
    var color: Color = AppColors.gold

    var body: some View {
        Text(text)
            .font(AppFonts.bodyMedium(12))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
