// Parlance/Core/Services/AuthService.swift
import Combine
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: Supabase.User?
    @Published private(set) var isAuthenticated = false
    @Published var pendingAppleDisplayName: String?

    var currentUserID: String? {
        #if DEBUG
        if let testOverrideUserID { return testOverrideUserID }
        #endif
        return currentUser?.id.uuidString
    }

    #if DEBUG
    /// UI-test-only override. When set via `_uiTestSeedAuthenticated(userID:)`,
    /// `currentUserID` returns this string and the auth state listener is
    /// skipped — see init().
    private var testOverrideUserID: String?
    #endif
    @Published private(set) var isLoading = true
    @Published var isCompletingSignUp = false
    @Published var isDeletingAccount = false
    @Published var didJustSignIn = false

    private let client = SupabaseManager.shared.client

    init() {
        #if DEBUG
        // UI-test bootstrap: when `--ui-test-seed-pro` is set, skip the
        // Supabase auth listener entirely so UITestBootstrap can seed
        // auth state synchronously without race conditions.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-seed-pro") {
            isLoading = false
            return
        }
        #endif
        Task { await listenToAuthChanges() }
    }

    #if DEBUG
    /// UI-test-only: seed an authenticated session without going through
    /// Supabase. Called by `UITestBootstrap` when the `--ui-test-seed-pro`
    /// launch arg is present.
    func _uiTestSeedAuthenticated(userID: String) {
        testOverrideUserID = userID
        isAuthenticated = true
        isLoading = false
    }
    #endif

    private func listenToAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession:
                currentUser = session?.user
                isAuthenticated = session != nil
            case .signedIn, .tokenRefreshed:
                // Only update if there's a real session; a nil-session signedIn event
                // can fire after sign-up when email confirmation is required — don't
                // override the auth state we already set in signUp().
                if let session {
                    currentUser = session.user
                    isAuthenticated = true
                }
            case .signedOut:
                currentUser = nil
                isAuthenticated = false
            default:
                break
            }
            if isLoading { isLoading = false }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        // Treat account creation as authenticated immediately.
        // Email confirmation is not enforced yet — TODO before production.
        currentUser = response.user
        isAuthenticated = true
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
    }

    func signOut() async throws {
        // Delete the push token first while we still have an authenticated session.
        await PushTokenService.shared.deleteToken()
        try await client.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func deleteAccount() async throws {
        guard currentUserID != nil else { return }
        isDeletingAccount = true
        do {
            try await deleteAccountViaWorker()
            PersistenceService.shared.resetAllData()
            try? await signOut()
            // isDeletingAccount stays true until the splash dismisses it
        } catch {
            isDeletingAccount = false
            throw error
        }
    }

    private func deleteAccountViaWorker() async throws {
        let session = try await client.auth.session
        let endpoint = AppConstants.apiBaseURL.appendingPathComponent("delete-user")
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
