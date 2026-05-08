// Parlance/Core/Services/AuthService.swift
import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: Supabase.User?
    @Published private(set) var isAuthenticated = false
    @Published var pendingAppleDisplayName: String?

    var currentUserID: String? { currentUser?.id.uuidString }
    @Published private(set) var isLoading = true
    @Published var isCompletingSignUp = false
    @Published var isDeletingAccount = false

    private let client = SupabaseManager.shared.client

    init() {
        Task { await listenToAuthChanges() }
    }

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
        try await client.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func deleteAccount() async throws {
        guard let uid = currentUserID else { return }
        isDeletingAccount = true
        do {
            try await deleteAuthUserViaWorker()
            let supabase = SupabaseManager.shared.client
            _ = try? await supabase.from("session_scores").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("user_stats").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("friend_requests").delete().eq("from_user_id", value: uid).execute()
            _ = try? await supabase.from("friendships").delete().or("user_id_1.eq.\(uid),user_id_2.eq.\(uid)").execute()
            _ = try? await supabase.from("profiles").delete().eq("id", value: uid).execute()
            PersistenceService.shared.resetAllData()
            try? await signOut()
            // isDeletingAccount stays true — AccountDeletedSplashView dismisses it via onDismiss
        } catch {
            isDeletingAccount = false
            throw error
        }
    }

    private func deleteAuthUserViaWorker() async throws {
        let session = try await client.auth.session
        let endpoint = AppConstants.apiBaseURL.appendingPathComponent("delete-user")
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
