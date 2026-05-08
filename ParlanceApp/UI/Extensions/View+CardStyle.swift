import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}
