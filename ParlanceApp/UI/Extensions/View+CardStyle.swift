import SwiftUI

extension View {
    func cardStyle(
        padding: CGFloat = 16,
        radius: CGFloat = AppConstants.cardRadius,
        background: Color = AppColors.card,
        borderColor: Color = AppColors.border,
        borderWidth: CGFloat = 1
    ) -> some View {
        self
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}
