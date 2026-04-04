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
                    dailyChallengeCard
                    difficultySlider
                    modeGrid
                    weeklyStatsRow
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

    private var headerRow: some View {
        HStack {
            if let user {
                Text("\(user.greeting), \(user.displayName)")
                    .font(AppFonts.bodyBold(20))
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            if let user {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(user.currentStreak)")
                        .font(AppFonts.bodyBold(16))
                        .foregroundStyle(AppColors.gold)

                    Text(user.avatarEmoji)
                        .font(.system(size: 24))
                }
            }
        }
    }

    private var xpBar: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
    }

    private var dailyChallengeCard: some View {
        Group {
            if let user {
                let mode = viewModel.dailyChallengeMode()
                let level = user.dailyChallengeLevelLock ?? user.practiceLevel
                DailyChallengeCard(mode: mode, level: level) {
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

    private var difficultySlider: some View {
        VStack(spacing: 8) {
            if let user {
                Slider(value: $sliderLevel, in: 1...10, step: 1)
                    .tint(AppColors.gold)
                    .onChange(of: sliderLevel) { _, newValue in
                        user.practiceLevel = Int(newValue)
                    }

                Text("Level \(Int(sliderLevel)) — \(DifficultyLevel.name(for: Int(sliderLevel)))")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .padding(.horizontal, 4)
    }

    private var modeGrid: some View {
        ModeGridView { mode in
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

    private var weeklyStatsRow: some View {
        let weekSessions = PersistenceService.shared.sessionsThisWeek()
        let stats = viewModel.weeklyStats(sessions: weekSessions)

        return HStack(spacing: 0) {
            statItem(value: "\(stats.count)", label: "Sessions")
            statItem(value: "\(stats.avgScore)", label: "Avg Score")
            statItem(value: "\(stats.bestScore)", label: "Best Score")
            statItem(value: "\(stats.fillerTotal)", label: "Fillers")
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
