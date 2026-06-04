import SwiftUI

/// A streak indicator that morphs from a small flame pill into a streak-stats
/// card. The collapsed pill is intrinsic-sized (matches the original Parlance
/// brand-row pill exactly) so the flame and digit sit tight inside the capsule.
/// The expanded card is rendered as an overlay anchored to the pill's
/// top-trailing corner, so brand-row layout never shifts.
struct HomeStreakShell: View {
    let currentStreak: Int
    let longestStreak: Int
    let lastSessionDate: Date?
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 162

    private var cornerRadius: CGFloat {
        isExpanded ? 18 : 13
    }

    var body: some View {
        // Invisible pill content acts as the layout anchor — sizes intrinsically,
        // matching the visible pill exactly so the brand row never shifts.
        pillFace
            .opacity(0)
            .accessibilityHidden(true)
            .overlay(alignment: .topTrailing) {
                shell
            }
    }

    private var shell: some View {
        Button {
            withAnimation(toggleAnimation) {
                isExpanded.toggle()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                pillFace
                    .opacity(isExpanded ? 0 : 1)

                cardFace
                    .frame(
                        width: isExpanded ? cardWidth : 0,
                        height: isExpanded ? cardHeight : 0,
                        alignment: .topLeading
                    )
                    .opacity(isExpanded ? 1 : 0)
                    .allowsHitTesting(isExpanded)
            }
            .frame(
                width: isExpanded ? cardWidth : nil,
                height: isExpanded ? cardHeight : nil,
                alignment: .topTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(isExpanded ? 0.22 : 0),
                radius: isExpanded ? 22 : 0,
                x: 0, y: 14
            )
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isExpanded ? "Double tap to close" : "Double tap to see streak details")
    }

    private var toggleAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.42, dampingFraction: 0.90)
    }

    // MARK: - Pill face
    // Intrinsic-sized: 10pt horizontal padding around the flame + digit, exactly like
    // the original Parlance brand-row pill. No fixed width, no Spacers — the capsule
    // wraps tight around the content.

    private var pillFace: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.gold)
            Text("\(currentStreak)")
                .font(AppFonts.bodyBold(12))
                .foregroundStyle(AppColors.gold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - Card face

    private var cardFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                Text("\(currentStreak)")
                    .font(AppFonts.display(50))
                    .foregroundStyle(AppColors.gold)
                    .contentTransition(.numericText())
                Text(currentStreak == 1 ? "day" : "days")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)
            }
            .padding(.bottom, 14)

            Rectangle()
                .fill(AppColors.border.opacity(0.7))
                .frame(height: 1)
                .padding(.bottom, 14)

            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(AppColors.faint)
                            .frame(width: 24, height: 24)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                    }
                    Text("Best streak")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.sub)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(displayedLongest)")
                        .font(AppFonts.bodyBold(17))
                        .foregroundStyle(AppColors.text)
                        .contentTransition(.numericText())
                    Text(displayedLongest == 1 ? "day" : "days")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.sub)
                }
            }
            .padding(.bottom, 10)

            Text(footnote)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    }

    // MARK: - Derived

    private var displayedLongest: Int {
        max(longestStreak, currentStreak)
    }

    private var footnote: String {
        if currentStreak == 0 {
            return "Start a session to begin a streak."
        }
        if currentStreak >= longestStreak {
            return "You're at your personal best. Keep going."
        }
        return "Show up tomorrow to keep it going."
    }

    private var accessibilityLabel: String {
        if isExpanded {
            return "\(currentStreak)-day streak. Best streak \(displayedLongest) days."
        }
        return "\(currentStreak)-day streak"
    }
}

#Preview("Collapsed (Light)") {
    PreviewWrapper(isExpanded: false)
        .environment(\.colorScheme, .light)
}

#Preview("Expanded (Light)") {
    PreviewWrapper(isExpanded: true)
        .environment(\.colorScheme, .light)
}

#Preview("Expanded (Dark)") {
    PreviewWrapper(isExpanded: true)
        .environment(\.colorScheme, .dark)
}

private struct PreviewWrapper: View {
    @State var isExpanded: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppColors.bg.ignoresSafeArea()
            HomeStreakShell(
                currentStreak: 1,
                longestStreak: 14,
                lastSessionDate: .now,
                isExpanded: $isExpanded
            )
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
    }
}
