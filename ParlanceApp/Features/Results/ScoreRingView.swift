import SwiftUI

struct ScoreRingView: View {
    let score: Int
    var size: CGFloat = 160
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }

    private var lineWidth: CGFloat { size * 0.075 }
    private var numberSize: CGFloat { size * 0.3 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(AppFonts.display(numberSize))
                .foregroundStyle(ringColor)
        }
        .frame(width: size, height: size)
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
