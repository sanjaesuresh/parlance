import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void

    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = HomeViewModel()

    private var user: User? { users.first }

    @State private var sliderLevel: Double = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerRow
                    xpBar
                    dailyChallengeSection
                    difficultySlider
                    modeGrid
                    weeklyStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .onAppear {
                if let user {
                    viewModel.lockDailyChallengeLevel(for: user)
                    sliderLevel = Double(user.practiceLevel)
                }
            }
            .alert("Daily Limit Reached", isPresented: $viewModel.showRateLimitAlert) {
                Button("OK") {}
            } message: {
                Text("You've hit your daily limit — come back tomorrow to keep your streak going.")
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            if let user {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.greeting.uppercased())
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                        .kerning(1.2)

                    Text("\(user.displayName).")
                        .font(AppFonts.display(28))
                        .foregroundStyle(AppColors.text)
                }
            }

            Spacer()

            if let user {
                HStack(spacing: 10) {
                    // Streak pill
                    HStack(spacing: 4) {
                        Text("\u{1F525}")
                            .font(.system(size: 13))
                        Text("\(user.currentStreak)")
                            .font(AppFonts.bodyBold(13))
                            .foregroundStyle(AppColors.gold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.card)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                    // Avatar circle
                    Text(user.avatarEmoji)
                        .font(.system(size: 18))
                        .frame(width: 38, height: 38)
                        .background(AppColors.card)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - XP Bar

    private var xpBar: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
    }

    // MARK: - Daily Challenge

    private var dailyChallengeSection: some View {
        Group {
            if let user {
                let mode = viewModel.dailyChallengeMode()
                let level = user.dailyChallengeLevelLock ?? user.practiceLevel
                let completed = user.hasDailyChallengeCompletedToday

                VStack(spacing: 10) {
                    // Section header row with bonus text
                    HStack {
                        SectionHeader(title: "Today's Challenge")
                        Spacer()
                        if completed {
                            Text("\u{2705} COMPLETED")
                                .font(AppFonts.bodyBold(11))
                                .foregroundStyle(AppColors.teal)
                        } else {
                            Text("+\(AppConstants.dailyChallengeXP) XP BONUS")
                                .font(AppFonts.bodyBold(11))
                                .foregroundStyle(AppColors.gold)
                        }
                    }

                    DailyChallengeCard(mode: mode, level: level, completed: completed) {
                        if !completed {
                            if let state = viewModel.startSession(
                                mode: mode,
                                user: user,
                                persistence: .shared,
                                wasDailyChallenge: true
                            ) {
                                onStartSession(state)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Difficulty Slider

    private var difficultySlider: some View {
        Group {
            if let user {
                VStack(spacing: 12) {
                    // Label row
                    HStack {
                        Text("Difficulty Level")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Text("\(DifficultyLevel.tier(for: Int(sliderLevel))) — Lv \(Int(sliderLevel))")
                            .font(AppFonts.bodyBold(13))
                            .foregroundStyle(AppColors.gold)
                    }

                    Slider(value: $sliderLevel, in: 1...10, step: 1)
                        .tint(AppColors.gold)
                        .onChange(of: sliderLevel) { _, newValue in
                            user.practiceLevel = Int(newValue)
                        }

                    // Tier labels spread across
                    HStack {
                        Text("Starter")
                        Spacer()
                        Text("Challenging")
                        Spacer()
                        Text("Intermediate")
                        Spacer()
                        Text("Advanced")
                        Spacer()
                        Text("Expert")
                    }
                    .font(AppFonts.body(9))
                    .foregroundStyle(AppColors.dim)
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
    }

    // MARK: - Mode Grid

    private var modeGrid: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Practice Modes")

            ModeGridView(level: Int(sliderLevel)) { mode in
                guard let user else { return }
                if let state = viewModel.startSession(
                    mode: mode,
                    user: user,
                    persistence: .shared,
                    wasDailyChallenge: false
                ) {
                    onStartSession(state)
                }
            }
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsSection: some View {
        let weekSessions = PersistenceService.shared.sessionsThisWeek()
        let stats = viewModel.weeklyStats(sessions: weekSessions)

        return VStack(spacing: 10) {
            SectionHeader(title: "This Week")

            HStack(spacing: 0) {
                statItem(value: "\(stats.count)", label: "Sessions")
                statItem(value: "\(stats.avgScore)", label: "Avg Score")
                statItem(value: "\(stats.bestScore)", label: "Best Score")
                statItem(value: "\(stats.fillerTotal)", label: "Fillers")
            }
            .cardStyle()
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(19))
                .foregroundStyle(AppColors.gold)
            Text(label)
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity)
    }
}
