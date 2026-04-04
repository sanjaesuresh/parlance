import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let levelName: String
    let tier: String
    let onReady: () -> Void

    @State private var statusIndex = 0
    @State private var pulseScale: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let statuses = [
        "Calibrating to your level…",
        "Selecting your challenge…",
        "Loading tips…",
        "Almost ready…"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(mode.accentColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(mode.accentColor.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale * 1.1)

                Circle()
                    .fill(mode.accentColor.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale * 1.2)
            }
            .onAppear {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }
            }

            Text(statuses[statusIndex])
                .font(AppFonts.body(16))
                .foregroundStyle(AppColors.sub)
                .animation(.easeInOut, value: statusIndex)

            VStack(spacing: 4) {
                Text(levelName)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                Text(tier)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                statusIndex = (statusIndex + 1) % statuses.count
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.loadingMinDuration) {
                onReady()
            }
        }
    }
}
