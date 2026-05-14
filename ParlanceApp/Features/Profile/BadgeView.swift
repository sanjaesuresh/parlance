import SwiftUI

/// Single circular badge used in the Profile badge row. Renders with a
/// tier-coloured ring when unlocked, a dim slate when locked.
struct BadgeView: View {
    let achievement: Achievement
    var size: CGFloat = 56

    private var tierColor: Color {
        switch achievement.tier {
        case 3: return AppColors.gold
        case 2: return AppColors.silver
        default: return AppColors.bronze
        }
    }

    private var ringColor: Color {
        achievement.isUnlocked ? tierColor : AppColors.border
    }

    private var background: Color {
        achievement.isUnlocked
            ? tierColor.opacity(0.16)
            : AppColors.card
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(background)

            Circle()
                .strokeBorder(ringColor, lineWidth: achievement.isUnlocked ? 2 : 1)

            if achievement.isUnlocked {
                Text(achievement.emoji)
                    .font(.system(size: size * 0.42))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
            }
        }
        .frame(width: size, height: size)
        .opacity(achievement.isUnlocked ? 1.0 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let tier = ["Bronze", "Silver", "Gold"][max(0, min(2, achievement.tier - 1))]
        if achievement.isUnlocked {
            return "\(tier) badge: \(achievement.name). Unlocked."
        }
        return "\(tier) badge: \(achievement.name). Locked. \(achievement.descriptionText)"
    }
}
