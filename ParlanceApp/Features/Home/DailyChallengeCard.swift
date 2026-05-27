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
                        Text("TODAY'S CHALLENGE")
                            .font(AppFonts.bodyBold(10))
                            .kerning(1.8)
                            .foregroundStyle(AppColors.dim)
                        Text(" · ")
                            .font(AppFonts.bodyBold(10))
                            .foregroundStyle(AppColors.dim)
                        if completed {
                            Text("COMPLETED")
                                .font(AppFonts.bodyBold(10))
                                .kerning(1.8)
                                .foregroundStyle(AppColors.teal)
                        } else {
                            Text("+\(AppConstants.dailyChallengeXP) XP")
                                .font(AppFonts.bodyBold(10))
                                .kerning(1.8)
                                .foregroundStyle(AppColors.gold)
                        }
                    }

                    Text(mode.displayName)
                        .font(AppFonts.display(20))
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
                        .fill(completed ? AppColors.teal : Color.clear)
                        .frame(width: 44, height: 44)
                    if !completed {
                        Circle()
                            .stroke(AppColors.gold, lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                    }
                    Image(systemName: completed ? "checkmark" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(completed ? AppColors.onGold : AppColors.gold)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.card2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.border, lineWidth: 1)
            )
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
