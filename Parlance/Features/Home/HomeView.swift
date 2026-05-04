import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void

    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var weekCache: SessionWeekCache

    private var user: User? { users.first }

    @State private var sliderLevel: Double = 1
    @State private var showPaywall = false

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
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [AppColors.bg, AppColors.bg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .onAppear {
                if let user {
                    viewModel.lockDailyChallengeLevel(for: user)
                    sliderLevel = Double(user.practiceLevel)
                }
            }
            .alert("Daily Limit Reached", isPresented: $viewModel.showRateLimitAlert) {
                Button("OK") {}
                if !subscription.isPro {
                    Button("Upgrade to Pro") { showPaywall = true }
                }
            } message: {
                Text(subscription.isPro
                    ? "You've completed 20 sessions today — come back tomorrow to keep your streak going."
                    : "Free accounts are limited to \(AppConstants.freeSessionsPerDay) sessions per day. Upgrade to Pro for unlimited sessions."
                )
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Parlance")
                    .font(AppFonts.display(28))
                    .foregroundStyle(AppColors.text)
                Text(".")
                    .font(AppFonts.display(28))
                    .foregroundStyle(AppColors.gold)
            }

            Spacer()

            if let user {
                HStack(spacing: 6) {
                    Text("🔥")
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(user.currentStreak)-day streak")
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
                                wasDailyChallenge: true,
                                isPro: subscription.isPro
                            ) {
                                onStartSession(state)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Difficulty Picker

    private let tiers: [(name: String, emoji: String, levels: ClosedRange<Int>)] = [
        ("Starter", "\u{1F331}", 1...2),
        ("Intermediate", "\u{1F4AA}", 3...4),
        ("Challenging", "\u{1F525}", 5...6),
        ("Advanced", "\u{26A1}", 7...8),
        ("Expert", "\u{1F451}", 9...10)
    ]

    private var selectedTierIndex: Int {
        tiers.firstIndex(where: { $0.levels.contains(Int(sliderLevel)) }) ?? 0
    }

    private var difficultySlider: some View {
        Group {
            if let user {
                VStack(spacing: 12) {
                    HStack {
                        Text("Difficulty Level")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Text("Lv \(Int(sliderLevel))")
                            .font(AppFonts.bodyBold(13))
                            .foregroundStyle(AppColors.gold)
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(tiers.enumerated()), id: \.offset) { index, tier in
                            let isSelected = index == selectedTierIndex
                            let isProTier = index >= 3
                            let locked = isProTier && !subscription.isPro

                            Button {
                                if locked {
                                    showPaywall = true
                                } else if isSelected {
                                    // Toggle between the two sub-levels
                                    let current = Int(sliderLevel)
                                    let next = current == tier.levels.lowerBound ? tier.levels.upperBound : tier.levels.lowerBound
                                    sliderLevel = Double(next)
                                    user.practiceLevel = Int(sliderLevel)
                                } else {
                                    sliderLevel = Double(tier.levels.lowerBound)
                                    user.practiceLevel = Int(sliderLevel)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    if locked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppColors.dim)
                                    } else {
                                        Text(tier.emoji)
                                            .font(.system(size: 16))
                                    }
                                    Text(tier.name)
                                        .font(AppFonts.bodyMedium(9))
                                        .foregroundStyle(locked ? AppColors.dim : (isSelected ? AppColors.gold : AppColors.sub))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? AppColors.gold.opacity(0.15) : AppColors.faint)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? AppColors.gold : Color.clear, lineWidth: 1.5)
                                )
                                .opacity(locked ? 0.5 : 1.0)
                            }
                            .accessibilityLabel("Difficulty \(tier.name)\(isSelected ? ", currently selected" : "")")
                            .accessibilityHint("Double-tap to select")
                        }
                    }
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

            ModeGridView(
                level: Int(sliderLevel),
                isPro: subscription.isPro,
                onSelect: { mode in
                    guard let user else { return }
                    if let state = viewModel.startSession(
                        mode: mode,
                        user: user,
                        persistence: .shared,
                        wasDailyChallenge: false,
                        isPro: subscription.isPro
                    ) {
                        onStartSession(state)
                    }
                },
                onSelectLocked: { _ in
                    showPaywall = true
                }
            )
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsSection: some View {
        let stats = viewModel.weeklyStats(sessions: weekCache.sessions)

        return VStack(spacing: 10) {
            SectionHeader(title: "This Week")

            if weekCache.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.dim)
                    Text("Complete your first session to see weekly stats")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                    Text("Try a Daily Convo to get started")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .cardStyle()
            } else {
                HStack(spacing: 0) {
                    statItem(value: "\(stats.count)", label: "Sessions")
                    statItem(value: "\(stats.avgScore)", label: "Avg Score")
                    statItem(value: "\(stats.bestScore)", label: "Best Score")
                    statItem(value: "\(stats.fillerTotal)", label: "Fillers")
                }
                .cardStyle()
            }
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
