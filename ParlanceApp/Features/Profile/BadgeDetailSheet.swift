import SwiftUI

/// Bottom-sheet detail for a single badge. Always shows the unlock criteria
/// (per product decision: criteria are educational, GitHub-style) plus
/// either the unlock date or current progress toward the goal.
struct BadgeDetailSheet: View {
    let achievement: Achievement

    @Environment(\.dismiss) private var dismiss

    private var tierColor: Color {
        switch achievement.tier {
        case 3: return AppColors.gold
        case 2: return AppColors.silver
        default: return AppColors.bronze
        }
    }

    private var tierLabel: String {
        ["Bronze", "Silver", "Gold"][max(0, min(2, achievement.tier - 1))]
    }

    private var categoryLabel: String {
        switch achievement.category {
        case "score":       return "Score"
        case "streak":      return "Streak"
        case "consistency": return "Consistency"
        case "volume":      return "Volume"
        case "variety":     return "Variety"
        case "mastery":     return "Mastery"
        default:            return achievement.category.capitalized
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppColors.bg)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .center, spacing: 18) {
            BadgeView(achievement: achievement, size: 96)

            VStack(spacing: 8) {
                tierEyebrow
                Text(achievement.name)
                    .font(AppFonts.display(24))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
            }

            Text(achievement.descriptionText)
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)

            Divider().background(AppColors.border)
                .padding(.vertical, 4)

            statusRow
        }
    }

    private var tierEyebrow: some View {
        HStack(spacing: 6) {
            Text(tierLabel)
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
                .foregroundStyle(tierColor)
            Text("·")
                .foregroundStyle(AppColors.dim)
            Text(categoryLabel)
                .font(AppFonts.bodyMedium(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if achievement.isUnlocked, let unlockedDate = achievement.unlockedDate {
            VStack(spacing: 6) {
                Text("UNLOCKED")
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.4)
                    .foregroundStyle(AppColors.teal)
                Text(unlockedDate.formatted(.dateTime.month(.wide).day().year()))
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.text)
            }
        } else if achievement.isUnlocked {
            Text("UNLOCKED")
                .font(AppFonts.bodyBold(10))
                .kerning(1.4)
                .foregroundStyle(AppColors.teal)
        } else if achievement.goal > 1 {
            VStack(spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(AppFonts.bodyBold(10))
                        .kerning(0.4)
                        .foregroundStyle(AppColors.dim)
                    Spacer()
                    Text("\(progressText) / \(goalText)")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.text)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.card2)
                        Capsule()
                            .fill(tierColor)
                            .frame(width: max(4, geo.size.width * achievement.progressFraction))
                    }
                }
                .frame(height: 6)
            }
        } else {
            Text("Locked")
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
        }
    }

    private var progressText: String {
        // Spoken-time goals are in seconds; render as hours for legibility.
        if achievement.id.hasPrefix("spoke_") {
            return "\(achievement.progress / 3600)h"
        }
        return "\(achievement.progress)"
    }

    private var goalText: String {
        if achievement.id.hasPrefix("spoke_") {
            return "\(achievement.goal / 3600)h"
        }
        return "\(achievement.goal)"
    }
}
