import SwiftUI

struct XPProgressBar: View {
    let currentXP: Int
    let rank: Rank

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    PillBadge(text: "LVL \(rank.level)", color: AppColors.gold, small: true)
                    Text(rank.name)
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                }
                Spacer()
                if rank.isMaxRank {
                    Text("MAX")
                        .font(AppFonts.bodyBold(11))
                        .foregroundStyle(AppColors.gold)
                } else {
                    let nextXP = rank.xpForNextRank ?? currentXP
                    Text("\(currentXP)/\(nextXP) XP")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                }
            }

            if rank.isMaxRank {
                ProgressBar(pct: 100, color: AppColors.gold)
            } else {
                let nextXP = rank.xpForNextRank ?? currentXP
                let progress = Double(currentXP - rank.xpRequired) / Double(max(1, nextXP - rank.xpRequired)) * 100
                ProgressBar(pct: progress, color: AppColors.gold)

                if let nextRank = Rank.forLevel(rank.level + 1) {
                    let remaining = nextXP - currentXP
                    HStack(spacing: 4) {
                        Text("\(remaining) XP to")
                            .font(AppFonts.body(11))
                            .foregroundStyle(Color(hex: "#333333"))
                        Text(nextRank.name)
                            .font(AppFonts.bodyBold(11))
                            .foregroundStyle(AppColors.gold)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
