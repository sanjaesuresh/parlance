import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let levelName: String
    let tier: String
    let onReady: () -> Void
    var onCancel: (() -> Void)?

    @State private var statusIndex = 0
    @State private var pulseScale: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let statuses = [
        "Calibrating to your level…",
        "Crafting your challenge…",
        "Tailoring tips…",
        "Almost ready…"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                if let onCancel {
                    Button(action: onCancel) {
                        Text("← Cancel")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Cancel")
                } else {
                    Spacer().frame(width: 72)
                }

                Spacer()

                PillBadge(text: "\(mode.emoji) \(mode.displayName)", color: mode.accentColor, small: true)

                Spacer()

                Spacer().frame(width: 72)
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
            .padding(.bottom, 8)

            Spacer()

            // Orb animation
            ZStack {
                Circle()
                    .fill(mode.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(mode.accentColor.opacity(0.2))
                    .frame(width: 76, height: 76)
                    .scaleEffect(pulseScale * 1.1)

                Circle()
                    .fill(mode.accentColor.opacity(0.4))
                    .frame(width: 52, height: 52)
                    .scaleEffect(pulseScale * 1.2)
                    .overlay(
                        Text(mode.emoji)
                            .font(.system(size: 26))
                    )
            }
            .onAppear {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }
            }

            Spacer().frame(height: 32)

            // Status text
            VStack(spacing: 10) {
                Text("Building your prompt…")
                    .font(AppFonts.display(22))
                    .foregroundStyle(AppColors.text)

                Text(statuses[statusIndex])
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
                    .animation(.easeInOut, value: statusIndex)
            }

            Spacer().frame(height: 28)

            // Difficulty card
            VStack(spacing: 6) {
                Text("YOUR DIFFICULTY")
                    .font(AppFonts.bodyMedium(10))
                    .foregroundStyle(AppColors.dim)
                    .kerning(1.0)

                Text(tier)
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(mode.accentColor)

                Text(levelName)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
                statusIndex = (statusIndex + 1) % statuses.count
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.loadingMinDuration) {
                onReady()
            }
        }
    }
}
