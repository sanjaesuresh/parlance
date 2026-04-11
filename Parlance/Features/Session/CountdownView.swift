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
        .onAppear { runCountdown() }
        .accessibilityElement()
        .accessibilityLabel("Countdown \(currentNumber)")
    }

    private func runCountdown() {
        if reduceMotion {
            // Skip animation and advance quickly
            Task {
                for n in stride(from: 3, through: 1, by: -1) {
                    currentNumber = n
                    scale = 1.0
                    opacity = 1.0
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }
                onComplete()
            }
            return
        }

        animateNumber(3) {
            animateNumber(2) {
                animateNumber(1) {
                    onComplete()
                }
            }
        }
    }

    private func animateNumber(_ number: Int, then: @escaping () -> Void) {
        currentNumber = number
        scale = 0.6
        opacity = 0.0

        withAnimation(.easeOut(duration: 0.25)) {
            scale = 1.1
            opacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.2)) {
                scale = 1.3
                opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                then()
            }
        }
    }
}
