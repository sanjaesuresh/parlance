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

    @Environment(\.scenePhase) private var scenePhase

    @State private var sectionVisible: [Bool] = Array(repeating: false, count: 6)
    @State private var sliderLevel: Double = 1
    @State private var showPaywall = false
    @State private var startSessionHaptic = false
    @State private var difficultyHaptic = false
    @State private var lockedHaptic = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerRow
                        .opacity(sectionVisible[0] ? 1 : 0)
                        .offset(y: sectionVisible[0] ? 0 : 16)
                    xpBar
                        .opacity(sectionVisible[1] ? 1 : 0)
                        .offset(y: sectionVisible[1] ? 0 : 16)
                    dailyChallengeSection
                        .opacity(sectionVisible[2] ? 1 : 0)
                        .offset(y: sectionVisible[2] ? 0 : 16)
                    difficultySlider
                        .opacity(sectionVisible[3] ? 1 : 0)
                        .offset(y: sectionVisible[3] ? 0 : 16)
                    modeGrid
                        .opacity(sectionVisible[4] ? 1 : 0)
                        .offset(y: sectionVisible[4] ? 0 : 16)
                    weeklyStatsSection
                        .opacity(sectionVisible[5] ? 1 : 0)
                        .offset(y: sectionVisible[5] ? 0 : 16)
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
            .sensoryFeedback(.impact(weight: .medium), trigger: startSessionHaptic)
            .sensoryFeedback(.selection, trigger: difficultyHaptic)
            .sensoryFeedback(.warning, trigger: lockedHaptic)
        }
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
                                startSessionHaptic.toggle()
                                onStartSession(state)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Difficulty Picker

    private struct Band: Identifiable {
        let id: Int           // lower bound stored in practiceLevel (1, 3, 5, 7, 9)
        let range: String
        let tierName: String
        let descriptor: String
        let isProTier: Bool
    }

    private let difficultyBands: [Band] = [
        Band(id: 1, range: "1–2", tierName: "Starter",    descriptor: "Build the habit",     isProTier: false),
        Band(id: 3, range: "3–4", tierName: "Developing", descriptor: "Finding your rhythm",  isProTier: false),
        Band(id: 5, range: "5–6", tierName: "Confident",  descriptor: "In the groove",        isProTier: false),
        Band(id: 7, range: "7–8", tierName: "Advanced",   descriptor: "High stakes",           isProTier: true),
        Band(id: 9, range: "9–10", tierName: "Expert",    descriptor: "The edge",              isProTier: true),
    ]

    private var selectedBandId: Int {
        let level = Int(sliderLevel)
        switch level {
        case 1...2: return 1
        case 3...4: return 3
        case 7...8: return 7
        case 9...10: return 9
        default:   return 5
        }
    }

    private var difficultySlider: some View {
        Group {
            if let user {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Difficulty")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Text(difficultyBands.first(where: { $0.id == selectedBandId })?.tierName ?? "")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(difficultyBands) { band in
                                    let isSelected = selectedBandId == band.id
                                    let locked = band.isProTier && !subscription.isPro

                                    Button {
                                        if locked {
                                            lockedHaptic.toggle()
                                            showPaywall = true
                                        } else if Int(sliderLevel) != band.id {
                                            difficultyHaptic.toggle()
                                            sliderLevel = Double(band.id)
                                            user.practiceLevel = band.id
                                        }
                                    } label: {
                                        bandCard(band, isSelected: isSelected, locked: locked)
                                    }
                                    .id(band.id)
                                    .accessibilityLabel("\(band.tierName), levels \(band.range)\(isSelected ? ", selected" : "")")
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 16)
                            .padding(.bottom, 14)
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .onAppear {
                            DispatchQueue.main.async {
                                proxy.scrollTo(selectedBandId, anchor: .leading)
                            }
                        }
                    }
                }
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
        }
    }

    private func bandAccentColor(_ band: Band) -> Color {
        switch band.id {
        case 1:  Color(red: 0.27, green: 0.80, blue: 0.47)   // green
        case 3:  Color(red: 0.20, green: 0.73, blue: 0.86)   // teal
        case 5:  AppColors.gold                                 // gold (existing)
        case 7:  Color(red: 1.00, green: 0.55, blue: 0.25)   // orange
        default: Color(red: 0.93, green: 0.35, blue: 0.35)   // coral/red
        }
    }

    private func bandCard(_ band: Band, isSelected: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 0) {
                Text(band.range)
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(isSelected ? bandAccentColor(band) : AppColors.dim)
                    .kerning(0.2)
                Spacer()
                if locked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .bold))
                        Text("PRO")
                            .font(AppFonts.bodyBold(8))
                    }
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            Text(band.tierName)
                .font(AppFonts.bodyBold(17))
                .foregroundStyle(isSelected ? AppColors.text : AppColors.sub)

            Text(band.descriptor)
                .font(AppFonts.body(11))
                .foregroundStyle(isSelected ? AppColors.sub : AppColors.dim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(width: 158, alignment: .leading)
        .background(
            isSelected
                ? bandAccentColor(band).opacity(0.10)
                : bandAccentColor(band).opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    isSelected
                        ? bandAccentColor(band).opacity(0.75)
                        : bandAccentColor(band).opacity(0.25),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .opacity(locked ? 0.55 : 1.0)
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
