import SwiftUI

struct ModeGridView: View {
    let onSelect: (SessionMode) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SessionMode.allCases, id: \.self) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    VStack(spacing: 8) {
                        Text(mode.emoji)
                            .font(.system(size: 32))
                        Text(mode.displayName)
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityLabel("\(mode.displayName) practice mode")
            }
        }
    }
}
