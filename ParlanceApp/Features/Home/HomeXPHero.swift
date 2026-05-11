import SwiftUI

struct HomeXPHero: View {
    let user: User
    let weeklySessionCount: Int
    let weeklyAvgScore: Int

    private var progressPct: Double {
        let rank = user.rank
        guard !rank.isMaxRank, let next = rank.xpForNextRank else { return 1.0 }
        let span = max(1, next - rank.xpRequired)
        return min(1, max(0, Double(user.xp - rank.xpRequired) / Double(span)))
    }

    private var nextRankLine: String {
        let rank = user.rank
        if rank.isMaxRank { return "Max rank reached" }
        let next = rank.xpForNextRank ?? user.xp
        let nextName = Rank.forLevel(rank.level + 1)?.name ?? "next level"
        return "\(user.xp) of \(next) xp to Level \(rank.level + 1) — \(nextName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("🔥").font(.system(size: 13))
                    Text("\(user.currentStreak)")
                        .font(AppFonts.bodyBold(13))
                        .foregroundStyle(AppColors.text)
                    Text("day streak")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                }
                Spacer()
                Text("L\(user.rank.level) · \(user.rank.name.uppercased())")
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.4)
                    .foregroundStyle(AppColors.gold)
            }
            .padding(.bottom, 10)

            Text("Day \(max(user.currentStreak, 1)).")
                .font(AppFonts.display(32))
                .foregroundStyle(AppColors.text)
                .padding(.bottom, 6)

            Text(nextRankLine)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
                .padding(.bottom, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.card2)
                    Capsule()
                        .fill(AppColors.gold)
                        .frame(width: geo.size.width * progressPct)
                }
            }
            .frame(height: 5)

            HStack {
                Text("This week · \(weeklySessionCount) session\(weeklySessionCount == 1 ? "" : "s")")
                Spacer()
                if weeklySessionCount > 0 {
                    Text("Avg \(weeklyAvgScore)")
                }
            }
            .font(AppFonts.body(11))
            .foregroundStyle(AppColors.sub)
            .padding(.top, 10)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColors.challengeGradientStart, AppColors.challengeGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.25), lineWidth: 1)
        )
    }
}
