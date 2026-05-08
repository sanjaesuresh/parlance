import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var weekCache = SessionWeekCache()
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("parlance.welcome_uid") private var pendingWelcomeUID = ""
    @State private var activeSession: ActiveSessionState?
    @State private var questionBank = QuestionBankService()
    @State private var showSplash = true
    @State private var isAppReady = false
    @State private var isSyncingProfile = false
    @EnvironmentObject private var authService: AuthService

    private var currentUser: User? {
        let uid = authService.currentUserID ?? ""
        return users.first { $0.supabaseUID == uid }
    }
    private var hasCompletedSetup: Bool { currentUser?.hasCompletedSetup ?? false }

    private var shouldShowWelcome: Bool {
        guard let user = currentUser, !pendingWelcomeUID.isEmpty else { return false }
        return pendingWelcomeUID == user.supabaseUID
    }

    var body: some View {
        ZStack {
            if showSplash || authService.isLoading || isSyncingProfile {
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
                FirstLaunchSetupView()
            } else if shouldShowWelcome, let user = currentUser {
                WelcomeSplashView(user: user) {
                    pendingWelcomeUID = ""
                }
                .transition(.opacity)
            } else if let session = activeSession {
                SessionCoordinator(
                    state: session,
                    onReshuffleQuestion: { [questionBank] newCategory in
                        guard let user = PersistenceService.shared.getUser() else { return nil }
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
                        }
                        weekCache.refresh()
                    }
                )
                .transition(.move(edge: .bottom))
            } else {
                mainTabView
            }
        }
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .environment(\.font, AppFonts.body(16))
        .environmentObject(permissionsService)
        .environmentObject(weekCache)
        .onAppear {
            PersistenceService.shared.seedAchievementsIfNeeded()
            if ProcessInfo.processInfo.arguments.contains("UITesting") {
                Task { try? await authService.signOut() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAppReady = true
            }
        }
        .overlay {
            if !networkMonitor.isConnected {
                NoConnectionView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, !authService.isCompletingSignUp else { return }
            Task {
                if currentUser == nil {
                    isSyncingProfile = true
                    await SyncService.shared.fetchAndImportProfile(uid: authService.currentUserID ?? "")
                    withAnimation { isSyncingProfile = false }
                }
                await SyncService.shared.flushIfNeeded()
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard isConnected, authService.isAuthenticated else { return }
            Task { await SyncService.shared.flushIfNeeded() }
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView(onStartSession: { state in
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeSession = state
                }
            })
            .environmentObject(weekCache)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            ProgressTabView()
                .environmentObject(weekCache)
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }

            LeagueView()
                .environmentObject(weekCache)
                .tabItem {
                    Label("League", systemImage: "trophy")
                }

            ProfileView()
                .environmentObject(weekCache)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .tint(AppColors.gold)
        .environmentObject(weekCache)
        .onAppear { weekCache.refresh() }
    }
}
