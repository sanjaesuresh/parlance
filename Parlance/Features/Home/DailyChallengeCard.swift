import SwiftUI

struct DailyChallengeCard: View {
    let mode: SessionMode
    let level: Int
    var completed: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Glow circle in top-right
                Circle()
                    .fill(AppColors.gold.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .offset(x: 40, y: -40)

                HStack {
                    // Left content
                    VStack(alignment: .leading, spacing: 10) {
                        // Pills row
                        HStack(spacing: 8) {
                            PillBadge(text: mode.displayName, emoji: mode.emoji, color: mode.accentColor, small: true)
                            PillBadge(text: "Lv \(level)", color: AppColors.gold, small: true)
                        }

                        // Title
                        Text("Daily Challenge")
                            .font(AppFonts.display(18))
                            .foregroundStyle(AppColors.text)

                        // Subtitle
                        if completed {
                            Text("Come back tomorrow for a new one")
                                .font(AppFonts.body(12))
                                .foregroundStyle(AppColors.teal)
                        } else {
                            Text("Fresh question every session")
                                .font(AppFonts.body(12))
                                .foregroundStyle(AppColors.dim)
                        }
                    }

                    Spacer()

                    // Play button / checkmark
                    ZStack {
                        Circle()
                            .fill(completed ? AppColors.teal : AppColors.gold)
                            .frame(width: 46, height: 46)

                        if completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.09, green: 0.07, blue: 0.0))
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.094, green: 0.071, blue: 0.0),
                        Color(red: 0.122, green: 0.090, blue: 0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke((completed ? AppColors.teal : AppColors.gold).opacity(0.3), lineWidth: 1)
            )
            .opacity(completed ? 0.7 : 1.0)
        }
        .disabled(completed)
        .accessibilityLabel(completed
            ? "Daily challenge completed"
            : "Daily challenge, \(mode.displayName), level \(level), plus \(AppConstants.dailyChallengeXP) XP"
        )
    }
}
