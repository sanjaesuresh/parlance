import SwiftUI

struct PillBadge: View {
    let text: String
    var color: Color = AppColors.gold
    var small: Bool = false

    var body: some View {
        Text(text)
            .font(AppFonts.bodyBold(small ? 10 : 12))
            .kerning(small ? 0.5 : 0)
            .foregroundStyle(color)
            .padding(.horizontal, small ? 9 : 13)
            .padding(.vertical, small ? 3 : 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
