import SwiftUI

struct AccountDeletedSplashView: View {
    let onDismiss: () -> Void

    @State private var dotsVisible: [Bool] = [false, false, false]
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var subtextOpacity: Double = 0
    @State private var exitOpacity: Double = 1
    @State private var exitOffset: CGFloat = 0

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Three gold dots — the "..." pause before speaking
                HStack(spacing: 14) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(AppColors.gold)
                            .frame(width: 11, height: 11)
                            .scaleEffect(dotsVisible[i] ? 1 : 0.01)
                            .opacity(dotsVisible[i] ? 1 : 0)
                    }
                }
                .padding(.bottom, 32)

                // Heading
                BouncingTitleView(text: "Sorry to see you go", fontSize: 30, animated: false)
                    .opacity(textOpacity)
                    .offset(y: textOffset)

                Spacer().frame(height: 10)

                Text("Your account has been permanently deleted.")
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(subtextOpacity)

                Spacer()
            }
            .opacity(exitOpacity)
            .offset(y: exitOffset)
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        // Dots stagger in
        for i in 0..<3 {
            withAnimation(.spring(duration: 0.38, bounce: 0.25).delay(0.1 + Double(i) * 0.16)) {
                dotsVisible[i] = true
            }
        }

        // Heading fades up
        withAnimation(.easeOut(duration: 0.42).delay(0.72)) {
            textOpacity = 1
            textOffset = 0
        }

        // Subtext fades in
        withAnimation(.easeOut(duration: 0.35).delay(1.0)) {
            subtextOpacity = 1
        }

        // Exit: slide down + fade out, then call onDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeIn(duration: 0.55)) {
                exitOpacity = 0
                exitOffset = 36
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            onDismiss()
        }
    }
}
