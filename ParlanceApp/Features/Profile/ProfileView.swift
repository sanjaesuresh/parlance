import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \Achievement.id) private var achievements: [Achievement]
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var router = DeepLinkRouter.shared
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var weekCache: SessionWeekCache
    @EnvironmentObject private var authService: AuthService
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showAvatarPicker = false
    @State private var showPaywall = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    private var user: User? {
        users.first { $0.supabaseUID == authService.currentUserID }
    }

    private let statsColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    levelCard
                    badgeRow
                    lifetimeSection
                    thisWeekSection
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
            .sheet(isPresented: $showAvatarPicker) {
                if let user {
                    AvatarPickerSheet(user: user, onDismiss: { showAvatarPicker = false })
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "profile")
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your profile")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(AppColors.dim)
                    .kerning(0.4)
                HStack(spacing: 0) {
                    Text("Profile")
                        .font(AppFonts.display(26))
                        .foregroundStyle(AppColors.text)
                    Text(".")
                        .font(AppFonts.display(26))
                        .foregroundStyle(AppColors.gold)
                }
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
                    .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settingsButton")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppColors.bg)
    }

    // MARK: - Editorial section header

    private func sectionTitle(_ title: String, trailing: AnyView? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
                .padding(.bottom, 22)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppFonts.display(18))
                    .foregroundStyle(AppColors.text)
                Spacer()
                if let trailing { trailing }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            if let user {
                Button {
                    showAvatarPicker = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(
                            avatarUrl: user.avatarUrl,
                            avatarEmoji: user.avatarEmoji,
                            avatarUpdatedAt: user.avatarUpdatedAt,
                            localOverride: user.profileImageData,
                            size: 80,
                            emojiFontSize: 38
                        )
                        .overlay(Circle().stroke(AppColors.gold.opacity(0.5), lineWidth: 2))

                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.onGold)
                            .frame(width: 26, height: 26)
                            .background(AppColors.gold)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColors.bg, lineWidth: 2))
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit avatar")

                HStack(spacing: 8) {
                    Text(user.displayName)
                        .font(AppFonts.display(24))
                        .foregroundStyle(AppColors.text)

                    if subscription.isPro {
                        Text("PRO")
                            .font(AppFonts.bodyBold(10))
                            .foregroundStyle(AppColors.onGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.gold)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text("LVL \(user.rank.level)")
                        .font(AppFonts.bodyBold(10))
                        .kerning(0.4)
                        .foregroundStyle(AppColors.gold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.gold.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.gold.opacity(0.35), lineWidth: 1))
                    Text("\(user.xp) XP")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.sub)
                    Text("·")
                        .foregroundStyle(AppColors.dim)
                    Text(user.rank.name)
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.sub)
                }
                .padding(.top, 2)

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }

                if let location = user.location, !location.isEmpty || (user.occupation?.isEmpty == false) {
                    HStack(spacing: 12) {
                        if let location = user.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                        }
                        if let occupation = user.occupation, !occupation.isEmpty {
                            Label(occupation, systemImage: "briefcase")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }

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
                    .overlay(Capsule().stroke(AppColors.gold.opacity(0.4), lineWidth: 1))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Level / XP card

    private var levelCard: some View {
        Group {
            if let user {
                let rank = user.rank
                let progressPct: Double = {
                    guard !rank.isMaxRank, let next = rank.xpForNextRank else { return 1.0 }
                    let span = max(1, next - rank.xpRequired)
                    return min(1, max(0, Double(user.xp - rank.xpRequired) / Double(span)))
                }()
                let nextRankName = Rank.forLevel(rank.level + 1)?.name

                Button {
                    router.selectedTab = 1
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(rank.name)
                                .font(AppFonts.display(20))
                                .foregroundStyle(AppColors.text)
                            Text("·")
                                .foregroundStyle(AppColors.dim)
                            Text("L\(rank.level)")
                                .font(AppFonts.bodyBold(11))
                                .kerning(0.4)
                                .foregroundStyle(AppColors.gold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.dim)
                        }
                        .padding(.bottom, 12)

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

                        HStack(alignment: .firstTextBaseline) {
                            if rank.isMaxRank {
                                Text("Max rank reached · \(user.xp) xp")
                                    .font(AppFonts.body(11))
                                    .foregroundStyle(AppColors.sub)
                            } else if let next = rank.xpForNextRank, let nextName = nextRankName {
                                let remaining = max(0, next - user.xp)
                                Text("\(user.xp) xp")
                                    .font(AppFonts.bodyBold(11))
                                    .foregroundStyle(AppColors.text)
                                Text("·")
                                    .font(AppFonts.body(11))
                                    .foregroundStyle(AppColors.dim)
                                Text("\(remaining) to \(nextName)")
                                    .font(AppFonts.body(11))
                                    .foregroundStyle(AppColors.sub)
                            }
                            Spacer()
                            Text("View progress")
                                .font(AppFonts.bodyMedium(11))
                                .foregroundStyle(AppColors.gold)
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.card2)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Level \(rank.level), \(rank.name). \(user.xp) XP. Tap to view progress.")
                .accessibilityIdentifier("profileLevelCard")
            }
        }
    }

    // MARK: - Lifetime stats

    private var lifetimeSection: some View {
        let totalSessions = sessions.count
        let hasSessions = totalSessions > 0
        let avgScore = hasSessions ? sessions.map(\.overallScore).reduce(0, +) / totalSessions : 0
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let totalSeconds = Int(sessions.map(\.duration).reduce(0, +))
        let totalTime = formatDuration(totalSeconds)
        let totalXP = sessions.map(\.xpEarned).reduce(0, +)
        let currentStreak = user?.currentStreak ?? 0
        let longestStreak = user?.longestStreak ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Lifetime")

            LazyVGrid(columns: statsColumns, spacing: 10) {
                statCell(value: hasSessions ? "\(totalSessions)" : "—", label: "Sessions")
                statCell(value: hasSessions ? "\(avgScore)" : "—", label: "Average score")
                statCell(value: hasSessions ? "\(bestScore)" : "—", label: "Best score")
                statCell(value: hasSessions ? "\(totalXP)" : "—", label: "Total XP")
                statCell(value: hasSessions ? totalTime : "—", label: "Time spoken")
                statCell(value: longestStreak > 0 ? "\(longestStreak)" : "—", label: "Longest streak")
            }

            if currentStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                    Text("On a ")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                    Text("\(currentStreak)-day streak")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(AppColors.gold)
                    Text(" right now")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                }
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFonts.display(24))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - This Week

    private var thisWeekSection: some View {
        let weekSessions = weekCache.sessions
        let weekCount = weekSessions.count
        let weekXP = weekSessions.map(\.xpEarned).reduce(0, +)
        let tier = LeagueTier.from(weeklyXP: weekXP)

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle("This week")

            HStack(spacing: 10) {
                weekCell(value: "\(weekCount)", label: "Sessions")
                weekCell(value: "\(weekXP)", label: "XP earned")
                weekCell(value: tier.displayName, label: "League", color: tier.color)
            }
        }
    }

    private func weekCell(value: String, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFonts.display(20))
                .foregroundStyle(color ?? AppColors.text)
            Text(label)
                .font(AppFonts.bodyMedium(10))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Badges (replaces the old achievementsSection grid)

    @ViewBuilder
    private var badgeRow: some View {
        if !achievements.isEmpty {
            BadgeRowView(achievements: Array(achievements))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Achievements")
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.dim)
                    Text("Achievements unlock as you practice.")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
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
