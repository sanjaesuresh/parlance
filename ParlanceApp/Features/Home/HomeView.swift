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

    private var thisWeekSessions: [Session] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        return allSessions.filter { $0.date >= weekStart }
    }

    @Environment(\.scenePhase) private var scenePhase

    @State private var sectionVisible: [Bool] = Array(repeating: false, count: 5)
    @State private var showPaywall = false
    @State private var showDifficultySheet = false
    @State private var startSessionHaptic = false
    @State private var difficultyHaptic = false
    @State private var lockedHaptic = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brandRow
                        .opacity(sectionVisible[0] ? 1 : 0)
                        .offset(y: sectionVisible[0] ? 0 : 16)
                    greetSection
                        .opacity(sectionVisible[1] ? 1 : 0)
                        .offset(y: sectionVisible[1] ? 0 : 16)
                    xpHeroSection
                        .opacity(sectionVisible[2] ? 1 : 0)
                        .offset(y: sectionVisible[2] ? 0 : 16)
                    dailyChallengeSection
                        .opacity(sectionVisible[3] ? 1 : 0)
                        .offset(y: sectionVisible[3] ? 0 : 16)
                    difficultySection
                        .opacity(sectionVisible[4] ? 1 : 0)
                        .offset(y: sectionVisible[4] ? 0 : 16)
                    modeGridSection
                        .opacity(sectionVisible[4] ? 1 : 0)
                        .offset(y: sectionVisible[4] ? 0 : 16)
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
                }
                animateIn()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background && newPhase == .active {
                    animateIn()
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
                PaywallView(source: "session_limit")
            }
            .sheet(isPresented: $showDifficultySheet) {
                if let user {
                    DifficultyChangeSheet(
                        selectedLevel: Binding(
                            get: { user.practiceLevel },
                            set: { user.practiceLevel = $0 }
                        ),
                        isPro: subscription.isPro,
                        onConfirm: { newLevel in
                            difficultyHaptic.toggle()
                            user.practiceLevel = newLevel
                        },
                        onUpgrade: {
                            lockedHaptic.toggle()
                            showDifficultySheet = false
                            showPaywall = true
                        }
                    )
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: startSessionHaptic)
            .sensoryFeedback(.selection, trigger: difficultyHaptic)
            .sensoryFeedback(.warning, trigger: lockedHaptic)
        }
    }

    // MARK: - Entrance Animation

    private func animateIn() {
        sectionVisible = Array(repeating: false, count: 5)
        let delays: [Double] = [0.05, 0.15, 0.25, 0.35, 0.45]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.4)) {
                    sectionVisible[i] = true
                }
            }
        }
    }

    // MARK: - Brand row

    private var brandRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Parlance")
                    .font(AppFonts.display(24))
                    .foregroundStyle(AppColors.text)
                Text(".")
                    .font(AppFonts.display(24))
                    .foregroundStyle(AppColors.gold)
            }

            Spacer()

            if let user {
                HStack(spacing: 6) {
                    Text("🔥").font(.system(size: 12))
                    Text("\(user.currentStreak)")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(AppColors.gold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(user.currentStreak)-day streak")
            }
        }
    }

    // MARK: - Greet

    private var greetSection: some View {
        Group {
            if let user {
                HomeGreeting(
                    user: user,
                    hasSessionsEver: !allSessions.isEmpty,
                    leveledUpRecently: false
                )
            }
        }
    }

    // MARK: - XP Hero

    private var xpHeroSection: some View {
        Group {
            if let user {
                let stats = viewModel.weeklyStats(sessions: thisWeekSessions)
                HomeXPHero(
                    user: user,
                    weeklySessionCount: stats.count,
                    weeklyAvgScore: stats.avgScore
                )
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

                VStack(alignment: .leading, spacing: 10) {
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
                                startSessionHaptic.toggle()
                                onStartSession(state)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Difficulty (quiet 5-tick bar)

    private struct Band: Identifiable {
        let id: Int
        let name: String
        let isPro: Bool
    }
    private let bands: [Band] = [
        Band(id: 1, name: "Starter",    isPro: false),
        Band(id: 3, name: "Developing", isPro: false),
        Band(id: 5, name: "Confident",  isPro: false),
        Band(id: 7, name: "Advanced",   isPro: true),
        Band(id: 9, name: "Expert",     isPro: true),
    ]
    private func bandId(for level: Int) -> Int {
        switch level {
        case 1...2: 1
        case 3...4: 3
        case 7...8: 7
        case 9...10: 9
        default: 5
        }
    }

    private var difficultySection: some View {
        Group {
            if let user {
                let currentId = bandId(for: user.practiceLevel)
                let currentName = bands.first(where: { $0.id == currentId })?.name ?? "Confident"

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeader(title: "Difficulty")
                        Spacer()
                        Button {
                            showDifficultySheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Change")
                                    .font(AppFonts.bodyMedium(11))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(AppColors.gold)
                        }
                        .accessibilityLabel("Change difficulty")
                    }

                    Text("Sets how challenging each session feels.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)

                    HStack(alignment: .firstTextBaseline) {
                        Text("\(currentName) · L\(user.practiceLevel)")
                            .font(AppFonts.display(20))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                    }
                    .padding(.top, 2)

                    HStack(spacing: 6) {
                        ForEach(bands) { band in
                            let on = band.id == currentId
                            let locked = band.isPro && !subscription.isPro
                            Capsule()
                                .fill(on
                                      ? AppColors.gold
                                      : (locked ? AppColors.card2.opacity(0.5) : AppColors.card2))
                                .frame(height: 4)
                        }
                    }

                    HStack {
                        Text("Starter")
                        Spacer()
                        Text("Expert · Pro")
                    }
                    .font(AppFonts.bodyBold(10))
                    .kerning(0.6)
                    .foregroundStyle(AppColors.dim)
                    .padding(.top, 2)
                }
                .padding(16)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { showDifficultySheet = true }
            }
        }
    }

    // MARK: - Mode Grid

    private var modeGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Practice Modes")
            ModeGridView(
                level: user?.practiceLevel ?? 5,
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
                        startSessionHaptic.toggle()
                        onStartSession(state)
                    }
                },
                onSelectLocked: { _ in
                    lockedHaptic.toggle()
                    showPaywall = true
                }
            )
        }
    }
}
