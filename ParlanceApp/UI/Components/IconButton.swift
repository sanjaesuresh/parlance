import SwiftUI

struct IconButton: View {
    let systemImage: String
    var accessibilityLabel: String
    var size: CGFloat = AppConstants.IconButton.size
    var glyphSize: CGFloat = AppConstants.IconButton.glyph
    var style: Style = .filled
    var isEnabled: Bool = true
    let action: () -> Void

    enum Style {
        case filled
        case bordered
        case plain
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                shape
                    .fill(background)
                    .frame(width: size, height: size)
                if case .bordered = style {
                    shape
                        .stroke(AppColors.border, lineWidth: 1)
                        .frame(width: size, height: size)
                }
                Image(systemName: systemImage)
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(foreground)
            }
            .frame(width: AppConstants.IconButton.hitTarget, height: AppConstants.IconButton.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var shape: Circle { Circle() }

    private var foreground: Color {
        if !isEnabled { return AppColors.disabled }
        switch style {
        case .filled:   return AppColors.onGold
        case .bordered, .plain: return AppColors.gold
        }
    }

    private var background: Color {
        if !isEnabled { return AppColors.disabled.opacity(0.3) }
        switch style {
        case .filled:
            return isPressed ? AppColors.gold.opacity(0.85) : AppColors.gold
        case .bordered:
            return isPressed ? AppColors.pressed : Color.clear
        case .plain:
            return isPressed ? AppColors.pressed : Color.clear
        }
    }
}
