import SwiftUI

struct HomeXPHero: View {
    let user: User
    let weeklySessionCount: Int
    let weeklyAvgScore: Int

    @Environment(\.colorScheme) private var colorScheme

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
        return "\(user.xp) of \(next) xp to Level \(rank.level + 1): \(nextName)"
    }

    private var gradientStart: Color { AppColors.coachCardGradientStart }
    private var gradientEnd: Color { AppColors.coachCardGradientEnd }

    private var onCardText: Color { AppColors.coachCardText }
    private var onCardSub: Color { AppColors.coachCardSub }
    private var onCardAccent: Color { AppColors.coachCardAccent }
    private var onCardTrack: Color { AppColors.coachCardTrack }
    private var onCardBorder: Color { AppColors.coachCardBorder }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(onCardAccent)
                    Text("\(user.currentStreak)")
                        .font(AppFonts.bodyBold(13))
                        .foregroundStyle(onCardText)
                    Text("day streak")
                        .font(AppFonts.body(12))
                        .foregroundStyle(onCardSub)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("L\(user.rank.level) · \(user.rank.name.uppercased())")
                        .font(AppFonts.bodyBold(10))
                        .kerning(1.4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(onCardAccent)
            }
            .padding(.bottom, 10)

            Text(user.currentStreak == 0 ? "Welcome back." : "Day \(user.currentStreak).")
                .font(AppFonts.display(32))
                .foregroundStyle(onCardText)
                .padding(.bottom, 6)

            Text(nextRankLine)
                .font(AppFonts.body(12))
                .foregroundStyle(onCardSub)
                .padding(.bottom, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(onCardTrack)
                    Capsule()
                        .fill(onCardAccent)
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
            .foregroundStyle(onCardSub)
            .padding(.top, 10)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [gradientStart, gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(onCardBorder, lineWidth: 1)
        )
    }
}
