import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var weekCache = SessionWeekCache()
    @ObservedObject private var router = DeepLinkRouter.shared
    @AppStorage("parlance.welcome_uid") private var pendingWelcomeUID = ""
    @AppStorage("parlance.welcome_back_uid") private var pendingWelcomeBackUID = ""
    @AppStorage("parlance.has_seen_teach") private var hasSeenTeach = false
    @State private var teachPracticeLevel: Int = 5
    @State private var activeSession: ActiveSessionState?
    @State private var pendingRealLifeEditText: String? = nil
    @State private var questionBank = QuestionBankService()
    @State private var showSplash = true
    @State private var isAppReady = false
    @State private var isSyncingProfile = false
    @State private var pendingResumeCandidate: ResumeCandidate?
    @State private var resumingAudioURL: URL?
    @State private var didCheckRecovery = false
    @State private var showStoreWipedAlert = false
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.scenePhase) private var scenePhase

    private var currentUser: User? {
        let uid = authService.currentUserID ?? ""
        return users.first { $0.supabaseUID == uid }
    }
    private var hasCompletedSetup: Bool { currentUser?.hasCompletedSetup ?? false }

    private var shouldShowWelcome: Bool {
        guard let user = currentUser, !pendingWelcomeUID.isEmpty else { return false }
        return pendingWelcomeUID == user.supabaseUID
    }

    private var shouldShowWelcomeBack: Bool {
        guard let user = currentUser, !pendingWelcomeBackUID.isEmpty else { return false }
        return pendingWelcomeBackUID == user.supabaseUID
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(isAppReady: isAppReady && !authService.isLoading && !isSyncingProfile) {
                    withAnimation { showSplash = false }
                }
                .ignoresSafeArea()
                .zIndex(1)
                .transition(.opacity)
            } else if authService.isDeletingAccount {
                AccountDeletedSplashView {
                    authService.isDeletingAccount = false
                }
                .transition(.opacity)
            } else if !authService.isAuthenticated {
                AuthView(authService: authService)
            } else if !hasCompletedSetup && !authService.isCompletingSignUp {
                if !hasSeenTeach {
                    OnboardingTeachView { level in
                        teachPracticeLevel = level
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasSeenTeach = true
                        }
                    }
                    .transition(.opacity)
                } else {
                    FirstLaunchSetupView(initialPracticeLevel: teachPracticeLevel)
                }
            } else if shouldShowWelcome, let user = currentUser {
                WelcomeSplashView(user: user) {
                    pendingWelcomeUID = ""
                }
                .transition(.opacity)
            } else if shouldShowWelcomeBack, let user = currentUser {
                WelcomeBackSplashView(user: user) {
                    pendingWelcomeBackUID = ""
                }
                .transition(.opacity)
            } else if let session = activeSession {
                SessionCoordinator(
                    state: session,
                    currentUserID: authService.currentUserID,
                    onReshuffleQuestion: { [questionBank] newCategory in
                        guard let uid = authService.currentUserID,
                              let user = PersistenceService.shared.getUser(uid: uid) else { return nil }
                        let band = session.question.difficultyBand
                        let seenIds = PersistenceService.shared.seenQuestionIds(
                            mode: session.mode,
                            band: band
                        )
                        guard let newQuestion = questionBank.selectQuestion(
                            mode: session.mode,
                            band: band,
                            category: newCategory,
                            excludingIds: seenIds
                        ) else {
                            return nil
                        }
                        user.lastExplanationCategory = newCategory
                        return newQuestion
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeSession = nil
                            resumingAudioURL = nil
                        }
                        weekCache.refresh()
                    },
                    onEditScenario: { originalScenario in
                        pendingRealLifeEditText = originalScenario
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeSession = nil
                            resumingAudioURL = nil
                        }
                    },
                    resumedAudioURL: resumingAudioURL
                )
                .transition(.move(edge: .bottom))
            } else {
                mainTabView
            }
        }
        .environment(\.font, AppFonts.body(16))
        .environmentObject(permissionsService)
        .environmentObject(weekCache)
        .onAppear {
            #if DEBUG
            PersistenceService.shared.cleanUITestResidueIfNeeded()
            #endif
            PersistenceService.shared.seedAchievementsIfNeeded()
            #if DEBUG
            // Visual-verification harness: seed the curated Progress-tab
            // dataset before any UI renders. ProgressMockData wipes existing
            // Session/User rows in the context so repeated launches are
            // deterministic. We also auth a synthetic user so ContentView's
            // gates fall straight through to mainTabView. Production builds
            // never see this branch.
            if CommandLine.arguments.contains("-mockProgressData") {
                ProgressMockData.seed(into: modelContext)
                authService._uiTestSeedAuthenticated(userID: "mock-progress-user")
            }
            #endif
            if ProcessInfo.processInfo.arguments.contains("UITesting") {
                #if DEBUG
                if UITestBootstrap.isSeedProEnabled {
                    UITestBootstrap.seedIfNeeded(authService: authService)
                } else {
                    Task { try? await authService.signOut() }
                }
                #else
                Task { try? await authService.signOut() }
                #endif
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAppReady = true
            }
            // Sweep orphaned temp recordings off the main thread so launch
            // perf is unaffected. Excludes the file we're about to recover.
            let activeAudio = ActiveSessionPersistence.shared.recoveryCandidate()?.audioURL
            Task.detached(priority: .background) {
                ActiveSessionPersistence.sweepOrphanedTempRecordings(excluding: activeAudio)
            }
        }
        .overlay {
            if !networkMonitor.isConnected {
                NoConnectionView()
                    .transition(.opacity)
            }
        }
        .sheet(item: $pendingResumeCandidate) { candidate in
            SessionRecoverySheet(
                candidate: candidate,
                onResume: {
                    let state = candidate.sessionState
                    let url = candidate.audioURL
                    pendingResumeCandidate = nil
                    resumingAudioURL = url
                    withAnimation(.easeInOut(duration: 0.3)) {
                        activeSession = state
                    }
                },
                onDiscard: {
                    let url = candidate.audioURL
                    pendingResumeCandidate = nil
                    try? FileManager.default.removeItem(at: url)
                    ActiveSessionPersistence.shared.clear()
                }
            )
        }
        .onChange(of: showSplash) { _, hidden in
            if !hidden { maybeOfferRecovery() }
        }
        .onChange(of: hasCompletedSetup) { _, completed in
            if completed { maybeOfferRecovery() }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, !authService.isCompletingSignUp else { return }
            Task {
                if currentUser == nil {
                    #if DEBUG
                    // UI-test seed already creates the local user synchronously
                    // and has no Supabase session to fetch from; awaiting the
                    // Supabase round-trip here keeps the splash up past the
                    // test's existence-wait window.
                    let skipSync = UITestBootstrap.isSeedProEnabled
                    #else
                    let skipSync = false
                    #endif
                    if !skipSync {
                        isSyncingProfile = true
                        await SyncService.shared.fetchAndImportProfile(uid: authService.currentUserID ?? "")
                        withAnimation { isSyncingProfile = false }
                    }
                }
                if authService.didJustSignIn,
                   let user = currentUser,
                   user.hasCompletedSetup,
                   pendingWelcomeUID != user.supabaseUID {
                    pendingWelcomeBackUID = user.supabaseUID
                }
                authService.didJustSignIn = false
                await SyncService.shared.flushIfNeeded()
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard isConnected, authService.isAuthenticated else { return }
            Task { await SyncService.shared.flushIfNeeded() }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase != .active && newPhase == .active {
                Task { await subscription.refreshStatus() }
            }
        }
        .alert("Local history was reset", isPresented: $showStoreWipedAlert) {
            Button("OK") {
                PersistenceService.acknowledgeStoreWipeNotice()
            }
        } message: {
            Text("We had to reset this device's session history after a storage issue. Your XP, streak, and friends were restored from the cloud, but the per-session details for older recordings could not be recovered.")
        }
    }

    private func maybeOfferRecovery() {
        guard !didCheckRecovery,
              !showSplash,
              authService.isAuthenticated,
              hasCompletedSetup,
              activeSession == nil,
              pendingResumeCandidate == nil else { return }
        didCheckRecovery = true
        if let candidate = ActiveSessionPersistence.shared.recoveryCandidate() {
            pendingResumeCandidate = candidate
        }
        // Surface the one-time "local data was reset" notice. The flag is set
        // by PersistenceService when a SwiftData migration failure forced a
        // wipe or an in-memory fallback. Synced stats (XP, streak, friends)
        // come back from Supabase on this launch; per-session history is
        // local-only and was lost.
        if PersistenceService.hasPendingStoreWipeNotice {
            showStoreWipedAlert = true
        }
    }

    private var mainTabView: some View {
        TabView(selection: $router.selectedTab) {
            HomeView(
                onStartSession: { state in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        activeSession = state
                    }
                },
                pendingRealLifeEditText: $pendingRealLifeEditText
            )
            .environmentObject(weekCache)
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            ProgressTabView()
                .environmentObject(weekCache)
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }
                .tag(1)

            LeagueView(openFriendRequests: $router.openFriendRequests)
                .environmentObject(weekCache)
                .tabItem {
                    Label("League", systemImage: "trophy")
                }
                .tag(2)

            ProfileView()
                .environmentObject(weekCache)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(3)
        }
        .tint(AppColors.gold)
        .environmentObject(weekCache)
        .onAppear { weekCache.refresh() }
    }
}
