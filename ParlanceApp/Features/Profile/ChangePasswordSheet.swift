import SwiftUI

struct ChangePasswordSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private static let minLength = 6

    private var newTooShort: Bool {
        !newPassword.isEmpty && newPassword.count < Self.minLength
    }

    private var mismatch: Bool {
        !confirmPassword.isEmpty && confirmPassword != newPassword
    }

    private var canSubmit: Bool {
        newPassword.count >= Self.minLength && newPassword == confirmPassword && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose a new password for your account. You'll stay signed in on this device.")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)

                    field(
                        label: "New password",
                        text: $newPassword,
                        isRevealed: $showNew,
                        contentType: .newPassword,
                        showError: newTooShort,
                        errorText: "Password must be at least \(Self.minLength) characters."
                    )

                    field(
                        label: "Confirm password",
                        text: $confirmPassword,
                        isRevealed: $showConfirm,
                        contentType: .newPassword,
                        showError: mismatch,
                        errorText: "Passwords don't match."
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(AppColors.onGold)
                            } else {
                                Text("Update password")
                                    .font(AppFonts.bodyBold(15))
                                    .foregroundStyle(AppColors.onGold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? AppColors.gold : AppColors.gold.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.sub)
                }
            }
            .alert("Password updated", isPresented: $didSucceed) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Use your new password the next time you sign in.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func field(
        label: String,
        text: Binding<String>,
        isRevealed: Binding<Bool>,
        contentType: UITextContentType,
        showError: Bool,
        errorText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.bodyMedium(12))
                .foregroundStyle(AppColors.sub)

            HStack(spacing: 0) {
                GoldSecureTextField(
                    text: text,
                    placeholder: label,
                    isRevealed: isRevealed.wrappedValue,
                    textContentType: contentType
                )
                .frame(height: 22)

                Button {
                    isRevealed.wrappedValue.toggle()
                } label: {
                    Image(systemName: isRevealed.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.gold)
                        .symbolEffect(.bounce, value: isRevealed.wrappedValue)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .frame(width: 28)
            }
            .padding(14)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? AppColors.red : AppColors.border, lineWidth: 1)
            )

            if showError {
                Text(errorText)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.red)
            }
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.updatePassword(newPassword: newPassword)
            didSucceed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
