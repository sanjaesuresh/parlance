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
    // Escalates 0 → 1 (light) → 2 (medium) → 3 (heavy) as the reveal animates
    @State private var splashHaptic = 0

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
        .sensoryFeedback(trigger: splashHaptic) { _, new in
            switch new {
            case 1: return .impact(weight: .light)
            case 2: return .impact(weight: .medium)
            case 3: return .impact(weight: .heavy)
            default: return nil
            }
        }
        .onAppear {
            appReady = isAppReady
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                splashHaptic = 1
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) { showFull = true }
                try? await Task.sleep(for: .seconds(0.3))
                splashHaptic = 2
                try? await Task.sleep(for: .seconds(0.3))
                splashHaptic = 3
                try? await Task.sleep(for: .seconds(0.3))
                revealDone = true
                scheduleIfReady()
            }
        }
        .onChange(of: isAppReady) { _, ready in
            appReady = ready
            scheduleIfReady()
        }
    }

    private func scheduleIfReady() {
        guard revealDone, appReady, !dismissScheduled else { return }
        dismissScheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeIn(duration: 0.4)) { fadeOut = true }
            try? await Task.sleep(for: .seconds(0.45))
            onFinished()
        }
    }
}
