import SwiftUI

struct ScoreRingView: View {
    let score: Int
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: 12)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(AppFonts.display(48))
                .foregroundStyle(ringColor)
        }
        .frame(width: 160, height: 160)
        .accessibilityElement()
        .accessibilityLabel("Overall score \(score) out of 100")
        .onAppear {
            if reduceMotion {
                animatedProgress = Double(score) / 100.0
            } else {
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animatedProgress = Double(score) / 100.0
                }
            }
        }
    }
}
