import SwiftUI

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    SwiftUI.ProgressView()
                        .tint(AppColors.gold)
                } else {
                    HStack(spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(title)
                            .font(AppFonts.bodyBold(16))
                    }
                    .foregroundStyle(foreground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.buttonRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled || isLoading)
    }

    private var foreground: Color {
        if !isEnabled { return AppColors.disabled }
        return AppColors.gold
    }

    private var background: Color {
        if isPressed { return AppColors.pressed }
        return Color.clear
    }

    private var borderColor: Color {
        if !isEnabled { return AppColors.disabled }
        return AppColors.gold.opacity(0.5)
    }
}
