import SwiftUI

/// Full-screen 3-2-1 countdown shown between the loading screen and the recording screen.
/// Calls `onComplete` once the animation finishes so the coordinator can auto-start the mic.
struct CountdownView: View {
    let accentColor: Color
    let onComplete: () -> Void

    @State private var currentNumber: Int = 3
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Get ready")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)

                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 220, height: 220)
                        .scaleEffect(scale * 0.9)

                    Circle()
                        .stroke(accentColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .scaleEffect(scale * 0.95)

                    Text("\(currentNumber)")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
                .frame(height: 240)
            }
        }
        .onAppear { Task { await runCountdown() } }
        .accessibilityElement()
        .accessibilityLabel("Countdown \(currentNumber)")
    }

    private func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            await MainActor.run {
                currentNumber = n
                if reduceMotion {
                    scale = 1.0
                    opacity = 1.0
                } else {
                    scale = 0.6
                    opacity = 0.0
                    withAnimation(.easeOut(duration: 0.25)) {
                        scale = 1.1
                        opacity = 1.0
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            if !reduceMotion {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        scale = 1.3
                        opacity = 0.0
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        await MainActor.run { onComplete() }
    }
}
