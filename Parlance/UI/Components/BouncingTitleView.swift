import SwiftUI

/// Displays a display-weight heading with an animated gold period at the end.
struct BouncingTitleView: View {
    let text: String
    var fontSize: CGFloat = 42

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text)
                .font(AppFonts.display(fontSize))
                .foregroundStyle(AppColors.text)
            KeyframeAnimator(initialValue: CGFloat(0), repeating: true) { offset in
                Text(".")
                    .font(AppFonts.display(fontSize))
                    .foregroundStyle(AppColors.gold)
                    .offset(y: offset)
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.45)
                SpringKeyframe(-13, duration: 0.26, spring: .init(duration: 0.26, bounce: 0))
                CubicKeyframe(2.5, duration: 0.20)
                CubicKeyframe(0, duration: 0.09)
            }
        }
    }
}
