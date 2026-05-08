import SwiftUI

struct WelcomeBackSplashView: View {
    let user: User
    let onDismiss: () -> Void

    @State private var avatarVisible = false
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var subtextOpacity: Double = 0
    @State private var exitOpacity: Double = 1
    @State private var exitOffset: CGFloat = 0

    private var firstName: String {
        user.displayName.components(separatedBy: " ").first ?? user.displayName
    }

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Avatar in gold ring
                ZStack {
                    Circle()
                        .fill(AppColors.gold.opacity(0.12))
                        .frame(width: 108, height: 108)
                    Circle()
                        .strokeBorder(AppColors.gold.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 108, height: 108)
                    Text(user.avatarEmoji)
                        .font(.system(size: 52))
                }
                .scaleEffect(avatarVisible ? 1 : 0.55)
                .opacity(avatarVisible ? 1 : 0)
                .padding(.bottom, 32)

                BouncingTitleView(text: "Welcome back, \(firstName)", fontSize: 30, animated: false)
                    .opacity(textOpacity)
                    .offset(y: textOffset)

                Spacer().frame(height: 10)

                Text("Picking up where you left off.")
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
        withAnimation(.spring(duration: 0.55, bounce: 0.28).delay(0.1)) {
            avatarVisible = true
        }

        withAnimation(.easeOut(duration: 0.42).delay(0.5)) {
            textOpacity = 1
            textOffset = 0
        }

        withAnimation(.easeOut(duration: 0.35).delay(0.78)) {
            subtextOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.55)) {
                exitOpacity = 0
                exitOffset = 36
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onDismiss()
        }
    }
}
