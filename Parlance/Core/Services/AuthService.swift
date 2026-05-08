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

    private let client = SupabaseManager.shared.client

    init() {
        Task { await listenToAuthChanges() }
    }

    private func listenToAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                currentUser = session?.user
                isAuthenticated = session != nil
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
        try await client.auth.signUp(email: email, password: password)
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
}
