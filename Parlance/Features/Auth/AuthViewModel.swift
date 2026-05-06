// Parlance/Features/Auth/AuthViewModel.swift
import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUp = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private(set) var pendingNonce: String?
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func submitEmailAuth() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        pendingNonce = nonce
        return sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8),
                let nonce = pendingNonce
            else {
                errorMessage = "Sign in with Apple failed. Please try again."
                return
            }
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
