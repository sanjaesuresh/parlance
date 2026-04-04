import SwiftUI

struct DailyChallengeCard: View {
    let mode: SessionMode
    let level: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Challenge")
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(.white)

                    Spacer()

                    PillBadge(text: "+\(AppConstants.dailyChallengeXP) XP", color: .white)
                }

                Text("\(mode.displayName) · Level \(level)")
                    .font(AppFonts.body(14))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.gold, AppColors.gold.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        }
        .accessibilityLabel("Daily challenge, \(mode.displayName), level \(level), plus \(AppConstants.dailyChallengeXP) XP")
    }
}
