import SwiftUI

struct UserProfileDetailView: View {
    let profile: SocialProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    statsGrid
                    recentScoresCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.gold)
                }
            }
            .toolbarBackground(AppColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.gold.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle().stroke(AppColors.gold.opacity(0.5), lineWidth: 2)
                    )
                    .overlay(
                        Text(profile.avatarEmoji)
                            .font(.system(size: 38))
                    )

                Text("LV \(profile.rank.level)")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.gold)
                    .clipShape(Capsule())
                    .offset(x: 4, y: 4)
            }

            Text(profile.displayName)
                .font(AppFonts.display(24))
                .foregroundStyle(AppColors.text)

            Text("@\(profile.username)")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)

            Text(profile.rank.name)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)

            // Location + Occupation
            HStack(spacing: 12) {
                if let location = profile.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.dim)
                        Text(location)
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
                if let occupation = profile.occupation {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.dim)
                        Text(occupation)
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }

            // Badges
            HStack(spacing: 8) {
                PillBadge(text: "\u{1F525} \(profile.currentStreak)-day streak", color: AppColors.gold, small: true)

                let tier = LeagueTier.from(weeklyXP: profile.weeklyXP)
                PillBadge(text: "\(tier.displayName) League", color: AppColors.purple, small: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        let statColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: statColumns, spacing: 10) {
            statCell(value: "\(profile.totalSessions)", label: "Sessions")
            statCell(value: "\(profile.avgScore)", label: "Avg Score")
            statCell(value: "\(profile.currentStreak)", label: "Day Streak")
            statCell(value: "\(profile.weeklyXP)", label: "Weekly XP")
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.gold)
            Text(label.uppercased())
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Recent Scores

    private var recentScoresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")

            if profile.recentScores.isEmpty {
                Text("No sessions yet")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            } else {
                ForEach(Array(profile.recentScores.enumerated()), id: \.offset) { index, score in
                    HStack {
                        Text("Session \(profile.recentScores.count - index)")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)

                        Spacer()

                        Text("\(score)")
                            .font(AppFonts.display(18))
                            .foregroundStyle(scoreColor(score))

                        // Score bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(scoreColor(score).opacity(0.5))
                            .frame(width: CGFloat(score), height: 6)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .cardStyle()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }
}
