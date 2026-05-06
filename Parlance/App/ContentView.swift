import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var weekCache = SessionWeekCache()
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue
    @State private var activeSession: ActiveSessionState?
    @State private var showSplash = true
    @State private var isAppReady = false
    @EnvironmentObject private var authService: AuthService

    private var currentUser: User? { users.first }
    private var hasCompletedSetup: Bool { currentUser?.hasCompletedSetup ?? false }

    var body: some View {
        ZStack {
            if showSplash || authService.isLoading {
                SplashView(isAppReady: isAppReady && !authService.isLoading) {
                    withAnimation { showSplash = false }
                }
                .ignoresSafeArea()
                .zIndex(1)
                .transition(.opacity)
            } else if !authService.isAuthenticated {
                AuthView(authService: authService)
            } else if !hasCompletedSetup {
                FirstLaunchSetupView()
            } else if let session = activeSession {
                SessionCoordinator(
                    state: session,
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
        .onAppear {
            PersistenceService.shared.seedAchievementsIfNeeded()
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
    }

    private var mainTabView: some View {
        TabView {
            HomeView(onStartSession: { state in
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeSession = state
                }
            })
            .tabItem {
                Label("Home", systemImage: "house")
            }

            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }

            LeagueView()
                .tabItem {
                    Label("League", systemImage: "trophy")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .tint(AppColors.gold)
        .environmentObject(weekCache)
        .onAppear { weekCache.refresh() }
    }
}
