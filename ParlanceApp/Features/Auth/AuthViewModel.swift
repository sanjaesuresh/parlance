// Parlance/Features/Auth/AuthViewModel.swift
import AuthenticationServices
import Combine
import CryptoKit
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUp = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True once a sign-up or reset-password request has been accepted and
    /// the user has been routed to the corresponding waiting screen. Used
    /// by AuthView to push the right navigation destination.
    @Published var pendingWaitingRoute: WaitingRoute?

    enum WaitingRoute: Hashable {
        case signupConfirmation
        case passwordReset
    }

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
            authService.didJustSignIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithProfile(name: String, username: String, location: String?, occupation: String?, avatar: String, comfortLevel: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Profanity check before touching the network
        let fieldsToCheck: [(String, String)] = [
            (name, "Name"),
            (username, "Username"),
            (location ?? "", "Location"),
            (occupation ?? "", "Occupation")
        ]
        for (value, label) in fieldsToCheck {
            if let rejection = ProfanityFilter.validate(value, fieldName: label) {
                errorMessage = rejection
                return
            }
        }

        do {
            try await authService.signUpWaitingConfirmation(email: email, password: password)
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            let finalUsername = username.isEmpty ? Self.makeUsername(from: trimmed) : username
            let loc = location.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            let occ = occupation.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            // Stash the profile fields on the auth service so they survive the
            // AuthView tear-down that happens when `.signedIn` fires after the
            // user confirms their email. ContentView reads this and finalizes
            // user creation + profile upload then.
            authService.pendingProfileSetup = .init(
                email: email,
                name: trimmed,
                username: finalUsername,
                location: loc,
                occupation: occ,
                avatar: avatar,
                practiceLevel: comfortLevel
            )
            pendingWaitingRoute = .signupConfirmation
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resendSignupConfirmation() async throws {
        guard let email = authService.pendingProfileSetup?.email else { return }
        try await authService.resendSignupConfirmation(email: email)
    }

    func resendPasswordReset() async throws {
        guard let email = authService.pendingResetEmail else { return }
        try await authService.sendPasswordReset(email: email)
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
            // Flag the in-flight reset as login-initiated so ContentView
            // keeps the user on AuthView once the recovery deep link
            // establishes a session, instead of dropping them into the
            // main app behind the change-password sheet.
            authService.isUnauthenticatedReset = true
            pendingWaitingRoute = .passwordReset
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
                authService.didJustSignIn = true
                let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
                let formattedName = nameParts.compactMap { $0 }.joined(separator: " ")
                if !formattedName.isEmpty {
                    authService.pendingAppleDisplayName = formattedName
                }
                // Best-effort: persist the Apple authorization code server-side so
                // account deletion can revoke the refresh token (App Store
                // Guideline 5.1.1(v)). Apple only emits authorizationCode on the
                // FIRST sign-in from a device, so this is one-shot — failures are
                // logged but never surface to the user (the sign-in itself
                // already succeeded). Must run AFTER signInWithApple so the JWT
                // is valid.
                if let codeData = credential.authorizationCode,
                   let code = String(data: codeData, encoding: .utf8),
                   !code.isEmpty {
                    do {
                        try await authService.registerAppleAuthorizationCode(code)
                    } catch {
                        #if DEBUG
                        print("[AuthViewModel] registerAppleAuthorizationCode failed: \(error)")
                        #endif
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        // Full unreserved set (note: previously missing 'W').
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        let count = charset.count
        // Largest multiple of `count` that fits in a byte. Bytes at/above this
        // are rejected so the modulo mapping is unbiased (256 % count != 0).
        let limit = 256 - (256 % count)
        var result = ""
        result.reserveCapacity(length)
        var byte: [UInt8] = [0]
        while result.count < length {
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { continue }
            let value = Int(byte[0])
            if value >= limit { continue }
            result.append(charset[value % count])
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
