import SwiftUI

struct XPProgressBar: View {
    let currentXP: Int
    let rank: Rank

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if rank.isMaxRank {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.gold)
                        .frame(width: geo.size.width, height: 10)
                }
                .frame(height: 10)

                Text("Rank 10 · Master · MAX")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.gold)
            } else {
                let nextXP = rank.xpForNextRank ?? currentXP
                let progress = Double(currentXP - rank.xpRequired) / Double(nextXP - rank.xpRequired)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.border)
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.gold)
                            .frame(width: max(0, geo.size.width * progress), height: 10)
                            .animation(.easeOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 10)

                Text("Rank \(rank.level) — \(rank.name) · \(currentXP) / \(nextXP) XP")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.sub)
            }
        }
    }
}
