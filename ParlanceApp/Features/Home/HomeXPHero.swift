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

    // Light mode: deep cinnamon → cocoa so cream text contrasts strongly.
    // Dark mode: keep the near-black warm wash that already reads well.
    private var gradientStart: Color {
        colorScheme == .dark ? Color(hex: "#181200") : Color(hex: "#C7813A")
    }
    private var gradientEnd: Color {
        colorScheme == .dark ? Color(hex: "#1F1700") : Color(hex: "#7A3F12")
    }

    // Bright warm cream for primary text on both modes — pops on the dark warm bg.
    private var onCardText: Color { Color(hex: "#FBF3E2") }
    // Muted cream for secondary lines; still well above 4.5:1 on the deep amber.
    private var onCardSub: Color { Color(hex: "#E8D3A6") }
    // Slightly brighter gold so the flame, level pill, and progress fill carry.
    private var onCardAccent: Color { Color(hex: "#F5C45A") }
    // Track for the progress bar — a dark espresso so the gold fill stands out.
    private var onCardTrack: Color { Color.black.opacity(0.28) }
    private var onCardBorder: Color { Color(hex: "#F5C45A").opacity(0.35) }

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
