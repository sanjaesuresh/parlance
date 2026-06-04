import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void
    @Binding var pendingRealLifeEditText: String?

    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var weekCache: SessionWeekCache
    @EnvironmentObject private var authService: AuthService
    @ObservedObject private var router = DeepLinkRouter.shared

    private var user: User? {
        users.first { $0.supabaseUID == authService.currentUserID }
    }

    private var thisWeekSessions: [Session] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
        return allSessions.filter { $0.date >= weekStart }
    }

    @Environment(\.scenePhase) private var scenePhase

    @State private var sectionVisible: [Bool] = Array(repeating: false, count: 6)
    @State private var showPaywall = false
    @State private var showDifficultySheet = false
    @State private var showRealLifeSetup = false
    @State private var realLifePrefill: String? = nil
    @State private var startSessionHaptic = false
    @State private var difficultyHaptic = false
    @State private var lockedHaptic = false
    @State private var streakExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                    allTimeStatsSection
                        .opacity(sectionVisible[5] ? 1 : 0)
                        .offset(y: sectionVisible[5] ? 0 : 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationBarHidden(true)
            .onScrollPhaseChange { _, newPhase in
                if streakExpanded, newPhase == .interacting || newPhase == .tracking {
                    withAnimation(streakAnimation) {
                        streakExpanded = false
                    }
                }
            }
            .overlay {
                if streakExpanded {
                    AppColors.bg
                        .opacity(0.6)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(streakAnimation) {
                                streakExpanded = false
                            }
                        }
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    brandRow
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .opacity(sectionVisible[0] ? 1 : 0)
                        .offset(y: sectionVisible[0] ? 0 : 16)
                        .background(AppColors.bg, ignoresSafeAreaEdges: .top)
                        .zIndex(1)
                    LinearGradient(
                        colors: [AppColors.bg, AppColors.bg.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)
                    .allowsHitTesting(false)
                }
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
                    ? "You've completed 20 sessions today. Come back tomorrow to keep your streak going."
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
            .fullScreenCover(isPresented: $showRealLifeSetup) {
                RealLifeSetupView(
                    level: user?.practiceLevel ?? 5,
                    prefillScenario: realLifePrefill,
                    onStart: { state in
                        showRealLifeSetup = false
                        startSessionHaptic.toggle()
                        realLifePrefill = nil
                        // Let the cover dismiss animation finish before the
                        // session coordinator's full-screen takeover transition.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onStartSession(state)
                        }
                    }
                )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: startSessionHaptic)
            .sensoryFeedback(.selection, trigger: difficultyHaptic)
            .sensoryFeedback(.warning, trigger: lockedHaptic)
            .sensoryFeedback(trigger: streakExpanded) { _, newValue in
                newValue ? .selection : .impact(weight: .light)
            }
            .onChange(of: pendingRealLifeEditText) { _, newValue in
                guard let text = newValue, !text.isEmpty else { return }
                realLifePrefill = text
                showRealLifeSetup = true
                pendingRealLifeEditText = nil
            }
        }
    }

    private var streakAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.42, dampingFraction: 0.90)
    }

    // MARK: - Entrance Animation

    private func animateIn() {
        sectionVisible = Array(repeating: false, count: 6)
        let delays: [Double] = [0.05, 0.15, 0.25, 0.35, 0.45, 0.55]
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
                HomeStreakShell(
                    currentStreak: user.currentStreak,
                    longestStreak: user.longestStreak,
                    lastSessionDate: user.lastSessionDate,
                    isExpanded: $streakExpanded
                )
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
                Button {
                    router.selectedTab = 1
                } label: {
                    HomeXPHero(
                        user: user,
                        weeklySessionCount: stats.count,
                        weeklyAvgScore: stats.avgScore
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Progress tab")
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

    private func bandColor(_ id: Int) -> Color {
        AppColors.difficultyRamp(band: id)
    }

    /// Editorial section header: hairline top + bold title.
    private func sectionTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
                .padding(.bottom, 22)
            Text(title)
                .font(AppFonts.display(18))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var difficultySection: some View {
        Group {
            if let user {
                let currentId = bandId(for: user.practiceLevel)
                let currentName = bands.first(where: { $0.id == currentId })?.name ?? "Confident"

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                            .padding(.bottom, 22)
                        HStack(alignment: .firstTextBaseline) {
                            Text("Difficulty")
                                .font(AppFonts.display(18))
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            Button {
                                showDifficultySheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Choose difficulty")
                                        .font(AppFonts.bodyMedium(12))
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
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("\(currentName) · L\(user.practiceLevel)")
                            .font(AppFonts.display(22))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                    }
                    .padding(.top, 2)

                    HStack(spacing: 6) {
                        ForEach(bands) { band in
                            let filled = band.id <= currentId
                            let locked = band.isPro && !subscription.isPro
                            Capsule()
                                .fill(filled
                                      ? bandColor(band.id)
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
                    .kerning(0.4)
                    .foregroundStyle(AppColors.dim)
                    .padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture { showDifficultySheet = true }
            }
        }
    }

    // MARK: - Mode Grid

    private var modeGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
                    .padding(.bottom, 22)
                Text("Pick a mode to start.")
                    .font(AppFonts.display(18))
                    .foregroundStyle(AppColors.text)
                Text("Tap any card to begin a session.")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ModeGridView(
                level: user?.practiceLevel ?? 5,
                isPro: subscription.isPro,
                onSelect: { mode in
                    if mode == .realLife {
                        showRealLifeSetup = true
                        return
                    }
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

    // MARK: - All-Time Stats

    private var allTimeStatsSection: some View {
        Group {
            if let user {
                let totalSessions = allSessions.count
                let avgScore = totalSessions == 0
                    ? 0
                    : allSessions.map(\.overallScore).reduce(0, +) / totalSessions
                let bestStreak = max(user.longestStreak, user.currentStreak)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                            .padding(.bottom, 22)
                        Text("All-time stats.")
                            .font(AppFonts.display(18))
                            .foregroundStyle(AppColors.text)
                        Text("Every session, every streak.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    let columns = [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ]
                    LazyVGrid(columns: columns, spacing: 10) {
                        allTimeStatCell(value: "\(user.xp)", label: "Total XP")
                        allTimeStatCell(value: "\(totalSessions)", label: "Sessions")
                        allTimeStatCell(value: totalSessions == 0 ? "—" : "\(avgScore)", label: "Avg Score")
                        allTimeStatCell(value: "\(bestStreak)", label: "Best Streak")
                    }
                }
            }
        }
    }

    private func allTimeStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.gold)
            Text(label)
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
