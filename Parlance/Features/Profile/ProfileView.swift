import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \Achievement.id) private var achievements: [Achievement]
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSafari = false
    @State private var safariURL: URL?

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
                    xpSection
                    achievementsSection
                    performanceByModeCard
                    recentSessionsSection
                    settingsSection
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
            .onAppear { viewModel.loadSettings() }
            .alert("Reset All Data", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) { viewModel.resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your sessions, XP, streaks, and achievements. This cannot be undone.")
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("YOUR PROFILE")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(1.2)
            Text("Profile")
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }

                Text(user.rank.name)
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.dim)

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
                    PillBadge(text: "\u{1F525} \(user.currentStreak)-day streak", color: AppColors.gold, small: true)

                    let weeklyXP = PersistenceService.shared.sessionsThisWeek().map(\.xpEarned).reduce(0, +)
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
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let totalMinutes = Int(sessions.map(\.duration).reduce(0, +) / 60)
        let streak = user?.currentStreak ?? 0

        let statColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: statColumns, spacing: 10) {
            keyStatCell(value: "\(totalSessions)", label: "Total Sessions")
            keyStatCell(value: "\(bestScore)", label: "Best Score")
            keyStatCell(value: "\(totalMinutes)m", label: "Time Spoken")
            keyStatCell(value: "\(streak)", label: "Day Streak")
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

    // MARK: - XP

    private var xpSection: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
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
                            Text(achievementEmoji(for: achievement.iconName))
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

    // MARK: - Performance by Mode

    private var performanceByModeCard: some View {
        let breakdown = SessionMode.allCases.map { mode in
            let modeSessions = sessions.filter { $0.mode == mode }
            return (mode: mode, count: modeSessions.count, bestScore: modeSessions.map(\.overallScore).max() ?? 0)
        }
        let totalSessions = max(1, breakdown.map(\.count).reduce(0, +))

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Performance By Mode")

            ForEach(breakdown, id: \.mode) { item in
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(item.mode.emoji)
                                .font(.system(size: 14))
                            Text(item.mode.displayName)
                                .font(AppFonts.body(13))
                                .foregroundStyle(AppColors.text)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(item.count) sessions")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                            Text("Best \(item.bestScore)")
                                .font(AppFonts.bodyMedium(11))
                                .foregroundStyle(item.mode.accentColor)
                        }
                    }
                    ProgressBar(
                        pct: Double(item.count) / Double(totalSessions) * 100,
                        color: item.mode.accentColor,
                        height: 4
                    )
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")

            ForEach(sessions.prefix(8), id: \.id) { session in
                HStack(spacing: 12) {
                    Text(session.mode.emoji)
                        .font(.system(size: 18))
                        .frame(width: 38, height: 38)
                        .background(session.mode.accentColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.mode.displayName)
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        HStack(spacing: 6) {
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.sub)
                            Text("\u{00B7}")
                                .foregroundStyle(AppColors.dim)
                            Text("\(Int(session.duration / 60))m")
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.sub)
                            Text("\u{00B7}")
                                .foregroundStyle(AppColors.dim)
                            Text(DifficultyLevel.tier(for: session.difficultyLevel))
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.sub)
                        }
                    }

                    Spacer()

                    Text("\(session.overallScore)")
                        .font(AppFonts.display(20))
                        .foregroundStyle(scoreColor(session.overallScore))
                }
                .padding(12)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Settings")

            VStack(spacing: 0) {
                // Toggles
                Toggle(isOn: Binding(
                    get: { viewModel.dailyReminderEnabled },
                    set: { viewModel.toggleDailyReminder($0) }
                )) {
                    Label("Daily Reminder", systemImage: "bell.fill")
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                }
                .tint(AppColors.gold)
                .padding(.vertical, 12)

                Divider().background(AppColors.border)

                Toggle(isOn: Binding(
                    get: { viewModel.soundEffectsEnabled },
                    set: { viewModel.toggleSoundEffects($0) }
                )) {
                    settingsLabel(emoji: "\u{1F514}", text: "Streak Notifications")
                }
                .tint(AppColors.gold)
                .padding(.vertical, 12)

                Divider().background(AppColors.border)

                menuRow(icon: "lock.shield", title: "Privacy Policy") {
                    safariURL = URL(string: "https://parlance.app/privacy")
                    showSafari = true
                }

                Divider().background(AppColors.border)

                menuRow(icon: "doc.text", title: "Terms of Service") {
                    safariURL = URL(string: "https://parlance.app/terms")
                    showSafari = true
                }

                Divider().background(AppColors.border)

                menuRow(icon: "trash", title: "Reset All Data", isDestructive: true) {
                    viewModel.showResetConfirmation = true
                }
            }
        }
        .cardStyle()
    }

    private func settingsLabel(emoji: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(text)
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.text)
        }
    }

    private func menuRow(emoji: String = "", icon: String = "", title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if !emoji.isEmpty {
                    Text(emoji)
                        .frame(width: 24)
                } else if !icon.isEmpty {
                    Image(systemName: icon)
                        .foregroundStyle(isDestructive ? AppColors.red : AppColors.sub)
                        .frame(width: 24)
                }
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(isDestructive ? AppColors.red : AppColors.text)
                Spacer()
                Text("\u{203A}")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.dim)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("Parlance v1.0 \u{00B7} Made with \u{1F3A4}")
            .font(AppFonts.body(10))
            .foregroundStyle(Color(hex: "#2A2A2A"))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }

    private func achievementEmoji(for iconName: String) -> String {
        switch iconName {
        case "mic.fill": return "\u{1F3A4}"
        case "flame.fill": return "\u{1F525}"
        case "briefcase.fill": return "\u{1F4BC}"
        case "star.fill": return "\u{2B50}"
        case "checkmark.seal.fill": return "\u{2705}"
        case "trophy.fill": return "\u{1F3C6}"
        case "repeat": return "\u{1F504}"
        case "crown.fill": return "\u{1F451}"
        default: return "\u{1F3AF}"
        }
    }
}
