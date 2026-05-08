// Parlance/Features/Auth/AuthViewModel.swift
import Foundation
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUp = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var resetEmailSent = false

    static let minPasswordLength = 6

    var isValidEmail: Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var isPasswordLongEnough: Bool {
        password.count >= Self.minPasswordLength
    }

    var canSubmit: Bool {
        guard isValidEmail, !password.isEmpty else { return false }
        if isSignUp { return isPasswordLongEnough }
        return true
    }

    private(set) var pendingNonce: String?
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func submitSignIn() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithProfile(name: String, username: String, occupation: String?, avatar: String, comfortLevel: Int) async {
        isLoading = true
        authService.isCompletingSignUp = true
        errorMessage = nil
        defer { isLoading = false; authService.isCompletingSignUp = false }
        do {
            try await authService.signUp(email: email, password: password)
            let uid = authService.currentUserID ?? ""
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            let finalUsername = username.isEmpty ? Self.makeUsername(from: trimmed) : username
            let occ = occupation.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            let user = PersistenceService.shared.createUser(
                supabaseUID: uid,
                name: trimmed,
                username: finalUsername,
                occupation: occ,
                avatar: avatar,
                practiceLevel: comfortLevel
            )
            try await SyncService.shared.createProfile(for: user, authService: authService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func makeUsername(from name: String) -> String {
        String(name.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(15))
    }

    func sendPasswordReset() async {
        guard isValidEmail else {
            errorMessage = "Enter your email address first."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.sendPasswordReset(email: email)
            resetEmailSent = true
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
                let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
                let formattedName = nameParts.compactMap { $0 }.joined(separator: " ")
                if !formattedName.isEmpty {
                    authService.pendingAppleDisplayName = formattedName
                }
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
