import SwiftUI

struct DailyChallengeCard: View {
    let mode: SessionMode
    let level: Int
    var completed: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !completed { onTap() } }) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 0) {
                        Text("Today's challenge")
                            .font(AppFonts.bodyBold(11))
                            .kerning(0.4)
                            .foregroundStyle(AppColors.dim)
                        Text(" · ")
                            .font(AppFonts.bodyBold(11))
                            .foregroundStyle(AppColors.dim)
                        if completed {
                            Text("Completed")
                                .font(AppFonts.bodyBold(11))
                                .kerning(0.4)
                                .foregroundStyle(AppColors.teal)
                        } else {
                            Text("+\(AppConstants.dailyChallengeXP) XP")
                                .font(AppFonts.bodyBold(11))
                                .kerning(0.4)
                                .foregroundStyle(AppColors.gold)
                        }
                    }

                    Text(mode.displayName)
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(AppColors.text)

                    Text(completed
                         ? "Come back tomorrow for a new one"
                         : mode == .explanation
                             ? "Level \(level) · \(SessionMode.dailyChallengeExplanationCategory().displayName)"
                             : "Level \(level) · Fresh question every day"
                    )
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(completed ? AppColors.teal : AppColors.gold)
                        .frame(width: 44, height: 44)
                        .shadow(color: AppColors.gold.opacity(completed ? 0 : 0.35), radius: 8, x: 0, y: 3)
                    Image(systemName: completed ? "checkmark" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.onGold)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.dailyChallengeBgStart, AppColors.dailyChallengeBgEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.dailyChallengeBorder, lineWidth: 1)
            )
            .shadow(color: AppColors.dailyChallengeShadow, radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(completed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(completed
            ? "Daily challenge completed"
            : "Today's challenge, \(mode.displayName), level \(level), plus \(AppConstants.dailyChallengeXP) XP"
        )
        .accessibilityAddTraits(completed ? [] : .isButton)
    }
}
