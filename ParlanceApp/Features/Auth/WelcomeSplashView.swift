import SwiftUI

struct WelcomeSplashView: View {
    let user: User
    let onDismiss: () -> Void

    @State private var phase: AnimationPhase = .hidden

    private enum AnimationPhase {
        case hidden, visible
    }

    private let modes: [(icon: String, name: String)] = [
        ("briefcase.fill", "Job Interview"),
        ("bubble.left.and.bubble.right.fill", "Daily Convo"),
        ("bolt.fill", "Impromptu"),
        ("book.fill", "Explain a Topic"),
    ]

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
                    AvatarView(
                        avatarUrl: user.avatarUrl,
                        avatarEmoji: user.avatarEmoji,
                        avatarUpdatedAt: user.avatarUpdatedAt,
                        localOverride: user.profileImageData,
                        size: 80,
                        emojiFontSize: 52
                    )
                }
                .scaleEffect(phase == .visible ? 1 : 0.55)
                .opacity(phase == .visible ? 1 : 0)
                .animation(.spring(duration: 0.3, bounce: 0.22), value: phase)

                Spacer().frame(height: 32)

                // "Welcome, [Name]." with bouncing period
                BouncingTitleView(text: "Welcome, \(firstName)", fontSize: 34)
                    .opacity(phase == .visible ? 1 : 0)
                    .offset(y: phase == .visible ? 0 : 18)
                    .animation(.easeOut(duration: 0.28).delay(0.05), value: phase)

                Spacer().frame(height: 8)

                Text("Your coach is ready.")
                    .font(AppFonts.body(17))
                    .foregroundStyle(AppColors.sub)
                    .opacity(phase == .visible ? 1 : 0)
                    .offset(y: phase == .visible ? 0 : 14)
                    .animation(.easeOut(duration: 0.25).delay(0.1), value: phase)

                Spacer().frame(height: 48)

                // Mode pills — horizontal scroll, no identical grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(modes.enumerated()), id: \.element.name) { i, mode in
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColors.gold)
                                Text(mode.name)
                                    .font(AppFonts.bodyMedium(13))
                                    .foregroundStyle(AppColors.text)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppColors.card)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
                            .opacity(phase == .visible ? 1 : 0)
                            .offset(x: phase == .visible ? 0 : 22)
                            .animation(
                                .easeOut(duration: 0.22).delay(0.14 + Double(i) * 0.03),
                                value: phase
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }

                Spacer()

                // CTA
                PrimaryButton(title: "Start practicing", action: onDismiss)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .opacity(phase == .visible ? 1 : 0)
                .offset(y: phase == .visible ? 0 : 24)
                .animation(.easeOut(duration: 0.25).delay(0.22), value: phase)
            }
        }
        .onAppear {
            phase = .visible
        }
    }
}
