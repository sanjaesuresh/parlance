import SwiftUI
import SwiftData

struct LeagueView: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = LeagueViewModel()

    private var weekSessions: [Session] {
        PersistenceService.shared.sessionsThisWeek()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weeklyStatsCard
                    countdownTimer
                    leaderboardSection
                    tierInfoCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("League")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsCard: some View {
        let sessions = weekSessions
        let weeklyXP = viewModel.weeklyXP(from: sessions)
        let tier = LeagueTier.from(weeklyXP: weeklyXP)

        return VStack(spacing: 12) {
            HStack {
                Text(tier.displayName + " Tier")
                    .font(AppFonts.display(24))
                    .foregroundStyle(tier.color)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(value: "\(weeklyXP)", label: "Weekly XP")
                statItem(value: "\(sessions.count)", label: "Sessions")
                statItem(value: "\(viewModel.weeklyBestScore(from: sessions))", label: "Best Score")
            }

            if let nextXP = tier.xpForNextTier {
                let remaining = nextXP - weeklyXP
                Text("\(remaining) XP to \(LeagueTier.allCases[LeagueTier.allCases.firstIndex(of: tier)! + 1].displayName)")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .cardStyle()
    }

    // MARK: - Countdown

    private var countdownTimer: some View {
        Text(viewModel.timeUntilReset())
            .font(AppFonts.bodyMedium(14))
            .foregroundStyle(AppColors.sub)
            .frame(maxWidth: .infinity)
            .cardStyle()
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.sub)

            Text("Compete with friends — invite someone to unlock the leaderboard")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)

            ShareLink(item: URL(string: "https://apps.apple.com/app/parlance")!) {
                Text("Invite Friends")
                    .font(AppFonts.bodyBold(14))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Tier Info

    private var tierInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tier Thresholds")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(LeagueTier.allCases, id: \.self) { tier in
                HStack {
                    Circle()
                        .fill(tier.color)
                        .frame(width: 10, height: 10)
                    Text(tier.displayName)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(tier.minXP)+ XP")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                }
            }
        }
        .cardStyle()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
