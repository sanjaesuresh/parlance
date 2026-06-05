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
    /// Set to true when Supabase emits a `.passwordRecovery` event after the
    /// reset-password universal link opens the app. The root view watches
    /// this flag and presents `ChangePasswordSheet`. Cleared once the user
    /// finishes or cancels.
    @Published var isPasswordRecovery = false

    /// Profile fields captured during sign-up but not committed until the
    /// user confirms their email. Lives on the service (not the view model)
    /// because the AuthView tear-down on `isAuthenticated → true` would
    /// otherwise drop it. ContentView reads this on the post-confirmation
    /// `.signedIn` event to actually create the local user + push the
    /// profile to Supabase.
    struct PendingProfileSetup {
        let email: String
        let name: String
        let username: String
        let location: String?
        let occupation: String?
        let avatar: String
        let practiceLevel: Int
    }
    @Published var pendingProfileSetup: PendingProfileSetup?

    /// Email the password-reset waiting screen displays. Set by
    /// `sendPasswordReset`. Cleared when the user backs out or the
    /// recovery deep link arrives.
    @Published var pendingResetEmail: String?

    /// True when the in-flight password reset was initiated from the
    /// signed-out login screen ("Forgot password?"). Drives the
    /// ContentView gate that keeps the user on the login screen even
    /// after the recovery session is established, and triggers a
    /// sign-out after the new password is set so the user has to sign
    /// in again with their new credentials.
    @Published var isUnauthenticatedReset = false

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
            case .passwordRecovery:
                // Supabase has already established a recovery session for the
                // user. Surface the flag so the root view can present the
                // change-password sheet, and clear the waiting-screen email
                // so any pending in-app waiting sheet dismisses cleanly.
                if let session {
                    currentUser = session.user
                    isAuthenticated = true
                }
                pendingResetEmail = nil
                isPasswordRecovery = true
            default:
                break
            }
            if isLoading { isLoading = false }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Creates the auth user but does NOT mark the session as authenticated.
    /// With "Confirm email" enabled in Supabase, the returned response has no
    /// session — Supabase emits `.signedIn` only after the user opens the
    /// confirmation link, at which point `listenToAuthChanges` flips
    /// `isAuthenticated`. The caller is responsible for stashing the
    /// pending profile data via `pendingProfileSetup` so ContentView can
    /// finalize it once that event arrives.
    func signUpWaitingConfirmation(email: String, password: String) async throws {
        _ = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: AppURLs.emailConfirm
        )
    }

    /// Re-sends the signup confirmation email. Used by the waiting screen
    /// after the 60s cooldown expires. Supabase rate-limits these server
    /// side; we display the SDK error on failure.
    func resendSignupConfirmation(email: String) async throws {
        try await client.auth.resend(
            email: email,
            type: .signup,
            emailRedirectTo: AppURLs.emailConfirm
        )
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
    }

    /// Sends the Apple authorization code to the worker so it can exchange it
    /// for a refresh token and persist it server-side. The refresh token is
    /// required to actually revoke Apple Sign-in during account deletion per
    /// App Store Guideline 5.1.1(v). Best-effort: Apple only emits the
    /// authorization code on the FIRST sign-in from a device, so if this call
    /// fails we cannot retry for the same user. Must be called AFTER
    /// `signInWithApple` so the Supabase JWT is valid.
    func registerAppleAuthorizationCode(_ code: String) async throws {
        let session = try await client.auth.session
        let endpoint = AppConstants.apiBaseURL.appendingPathComponent("apple/register")
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["authorization_code": code])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    func signOut() async throws {
        // Delete the push token first while we still have an authenticated session.
        await PushTokenService.shared.deleteToken()
        try await client.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: AppURLs.passwordReset)
        pendingResetEmail = email
    }

    /// Called from `.onOpenURL` / `.onContinueUserActivity` when an auth
    /// universal link opens the app. Handles two URL shapes:
    ///
    /// 1. Direct-verify URLs from our custom email templates:
    ///    `https://theparlance.app/<path>?token_hash=…&type=signup|recovery`.
    ///    These bypass Supabase's `/auth/v1/verify` redirect so the click
    ///    lands directly on a domain iOS claims for the app. We call
    ///    `verifyOTP` to consume the token. Email templates MUST use this
    ///    shape — the default `{{ .ConfirmationURL }}` template variable
    ///    routes through Supabase first and Safari swallows the universal
    ///    link before it can reach the app.
    ///
    /// 2. PKCE callback URLs (`?code=…`) and implicit-grant fragment URLs.
    ///    Handed to `session(from:)`. Currently only OAuth flows would hit
    ///    this branch since our email templates use shape (1).
    ///
    /// The SDK's `verifyOTP` emits `.signedIn` regardless of `type`, so
    /// for `type=recovery` we manually flip `isPasswordRecovery` here.
    func handleOpenURL(_ url: URL) async {
        #if DEBUG
        print("[AuthService] handleOpenURL: \(url.absoluteString)")
        #endif

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let tokenHash = queryItems.first(where: { $0.name == "token_hash" })?.value,
           let typeRaw = queryItems.first(where: { $0.name == "type" })?.value,
           let type = EmailOTPType(rawValue: typeRaw) {
            do {
                _ = try await client.auth.verifyOTP(tokenHash: tokenHash, type: type)
                if type == .recovery {
                    pendingResetEmail = nil
                    isPasswordRecovery = true
                }
            } catch {
                #if DEBUG
                print("[AuthService] verifyOTP failed: \(error)")
                #endif
            }
            return
        }

        do {
            try await client.auth.session(from: url)
        } catch {
            #if DEBUG
            print("[AuthService] session(from:) failed: \(error)")
            #endif
        }
    }

    func updatePassword(newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    /// True if the signed-in user has an email/password identity (i.e. can have a password to change).
    /// Apple-only users return false.
    var hasPasswordIdentity: Bool {
        guard let identities = currentUser?.identities else { return false }
        return identities.contains { $0.provider == "email" }
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
