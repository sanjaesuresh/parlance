import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \Achievement.id) private var achievements: [Achievement]
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var weekCache: SessionWeekCache
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showPaywall = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    private var user: User? { users.first }

    private let achievementColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    keyStatsGrid
                    achievementsSection
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                headerView
            }
            .onAppear {
                viewModel.loadSettings()
            }
            .alert("Reset All Data", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) { viewModel.resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your sessions, XP, streaks, and achievements. This cannot be undone.")
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(showPaywall: $showPaywall, viewModel: viewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                if let user {
                    ProfileEditSheet(user: user, onDismiss: { showEditProfile = false })
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR PROFILE")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(AppColors.dim)
                    .kerning(1.2)
                Text("Profile")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.sub)
                    .frame(width: 36, height: 36)
                    .background(AppColors.card)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppColors.bg)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            if let user {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.gold.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(AppColors.gold.opacity(0.5), lineWidth: 2)
                        )
                        .overlay(
                            Text(user.avatarEmoji)
                                .font(.system(size: 38))
                        )

                    Text("LV \(user.rank.level)")
                        .font(AppFonts.bodyBold(10))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.gold)
                        .clipShape(Capsule())
                        .offset(x: 4, y: 4)
                }

                Text(user.displayName)
                    .font(AppFonts.display(24))
                    .foregroundStyle(AppColors.text)

                if subscription.isPro {
                    Text("PRO")
                        .font(AppFonts.bodyBold(10))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(AppColors.gold)
                        .clipShape(Capsule())
                }

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }

                Text(user.rank.name)
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.dim)

                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Edit Profile")
                            .font(AppFonts.bodyMedium(12))
                    }
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppColors.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppColors.gold.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.top, 2)

                // Location + Occupation
                HStack(spacing: 12) {
                    if let location = user.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.dim)
                            Text(location)
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                        }
                    }
                    if let occupation = user.occupation, !occupation.isEmpty {
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

                HStack(spacing: 8) {
                    PillBadge(text: "\(user.currentStreak)-day streak", emoji: "🔥", color: AppColors.gold, small: true)

                    let weeklyXP = weekCache.sessions.map(\.xpEarned).reduce(0, +)
                    let tier = LeagueTier.from(weeklyXP: weeklyXP)
                    PillBadge(text: "\(tier.displayName) League", color: AppColors.purple, small: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Key Stats

    private var keyStatsGrid: some View {
        let totalSessions = sessions.count
        let hasSessions = totalSessions > 0
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let totalMinutes = Int(sessions.map(\.duration).reduce(0, +) / 60)
        let streak = user?.currentStreak ?? 0

        let statColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: statColumns, spacing: 10) {
            keyStatCell(value: hasSessions ? "\(totalSessions)" : "—", label: "Total Sessions")
            keyStatCell(value: hasSessions ? "\(bestScore)" : "—", label: "Best Score")
            keyStatCell(value: hasSessions ? "\(totalMinutes)m" : "—", label: "Time Spoken")
            keyStatCell(value: streak > 0 ? "\(streak)" : "—", label: "Day Streak")
        }
    }

    private func keyStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.gold)
            Text(label.uppercased())
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let unlockedCount = achievements.filter(\.isUnlocked).count

        return VStack(spacing: 12) {
            HStack {
                SectionHeader(title: "Achievements")
                Spacer()
                Text("\(unlockedCount) / \(achievements.count)")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }

            LazyVGrid(columns: achievementColumns, spacing: 8) {
                ForEach(achievements, id: \.id) { achievement in
                    VStack(spacing: 6) {
                        if achievement.isUnlocked {
                            Text(achievement.emoji)
                                .font(.system(size: 22))
                        } else {
                            Text("\u{1F512}")
                                .font(.system(size: 22))
                        }

                        Text(achievement.name)
                            .font(AppFonts.bodyMedium(9))
                            .foregroundStyle(AppColors.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        ZStack {
                            AppColors.card
                            if !achievement.isUnlocked {
                                Color.black.opacity(0.3)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(achievement.isUnlocked ? AppColors.gold.opacity(0.35) : AppColors.border, lineWidth: 1)
                    )
                    .opacity(achievement.isUnlocked ? 1.0 : 0.35)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("Parlance \u{00B7} Built for speakers.")
            .font(AppFonts.body(10))
            .foregroundStyle(AppColors.dim)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

}
