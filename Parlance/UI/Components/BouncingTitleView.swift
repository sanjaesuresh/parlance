import SwiftUI

/// Displays a display-weight heading with a gold period at the end.
/// Pass `animated: false` for a static period.
struct BouncingTitleView: View {
    let text: String
    var fontSize: CGFloat = 42
    var animated: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text)
                .font(AppFonts.display(fontSize))
                .foregroundStyle(AppColors.text)
            if animated {
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
            } else {
                Text(".")
                    .font(AppFonts.display(fontSize))
                    .foregroundStyle(AppColors.gold)
            }
        }
    }
}
