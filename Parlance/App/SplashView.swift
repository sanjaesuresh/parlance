import SwiftUI

struct SplashView: View {
    var isAppReady: Bool
    var onFinished: () -> Void

    @State private var showFull = false
    @State private var fadeOut = false
    // Mirrored into @State so asyncAfter closures always read the live value
    @State private var revealDone = false
    @State private var appReady = false
    @State private var dismissScheduled = false

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                Text("P")
                    .font(AppFonts.display(52))
                    .foregroundStyle(AppColors.text)

                Text("arlance")
                    .font(AppFonts.display(52))
                    .foregroundStyle(AppColors.text)
                    .fixedSize()
                    .frame(width: showFull ? nil : 0, alignment: .leading)
                    .clipped()
                    .opacity(showFull ? 1 : 0)

                Text(".")
                    .font(AppFonts.display(52))
                    .foregroundStyle(AppColors.gold)
            }
            .compositingGroup()
            .opacity(fadeOut ? 0 : 1)
            .scaleEffect(fadeOut ? 0.96 : 1)
            .animation(.easeIn(duration: 0.4), value: fadeOut)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            appReady = isAppReady

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                    showFull = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    revealDone = true
                    scheduleIfReady()
                }
            }
        }
        .onChange(of: isAppReady) { _, ready in
            appReady = ready
            scheduleIfReady()
        }
    }

    private func scheduleIfReady() {
        // All @State — closures always read live values
        guard revealDone, appReady, !dismissScheduled else { return }
        dismissScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                fadeOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onFinished()
            }
        }
    }
}
