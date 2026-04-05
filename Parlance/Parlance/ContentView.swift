import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @StateObject private var permissionsService = PermissionsService()
    @State private var activeSession: ActiveSessionState?

    private var currentUser: User? { users.first }
    private var hasCompletedSetup: Bool { currentUser?.hasCompletedSetup ?? false }

    var body: some View {
        ZStack {
            if !hasCompletedSetup {
                FirstLaunchSetupView()
            } else if let session = activeSession {
                SessionCoordinator(
                    state: session,
                    onDismiss: { activeSession = nil }
                )
                .transition(.move(edge: .bottom))
            } else {
                mainTabView
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.font, AppFonts.body(16))
        .environmentObject(permissionsService)
        .onAppear {
            PersistenceService.shared.seedAchievementsIfNeeded()
        }
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

            ProgressTabView()
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
    }
}
