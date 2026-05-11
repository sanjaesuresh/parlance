#if DEBUG
import Foundation

/// UI-test bootstrap. Activated by the `--ui-test-seed-pro` launch arg.
/// Seeds a Pro-tier authenticated session and a SwiftData User so UI
/// tests can land directly on the home tab without going through the
/// real Supabase auth + onboarding flow.
///
/// Companion changes:
/// - `AuthService.init()` short-circuits the Supabase listener when the
///   launch arg is set, then `_uiTestSeedAuthenticated(userID:)` is
///   called by `seedIfNeeded(authService:)` to mark the user signed in.
/// - `SubscriptionService.refreshStatus()` already auto-pros in
///   `DEBUG && simulator`, so no explicit Pro-state mock is needed for
///   simulator-based UI tests.
@MainActor
enum UITestBootstrap {
    static let testUserID = "11111111-2222-3333-4444-555555555555"
    static let seedProArg = "--ui-test-seed-pro"

    static var isSeedProEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(seedProArg)
    }

    /// Idempotent. Safe to call multiple times — only seeds state if the
    /// launch arg is set and the test user doesn't already exist.
    static func seedIfNeeded(authService: AuthService) {
        guard isSeedProEnabled else { return }

        authService._uiTestSeedAuthenticated(userID: testUserID)
        SubscriptionService.shared._uiTestSeedPro()

        let persistence = PersistenceService.shared
        if persistence.getUser(uid: testUserID) == nil {
            _ = persistence.createUser(
                supabaseUID: testUserID,
                name: "UI Test User",
                username: "uitest",
                location: nil,
                occupation: nil,
                avatar: "🧪",
                practiceLevel: 5
            )
        }
    }
}
#endif
