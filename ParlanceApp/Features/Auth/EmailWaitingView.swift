import SwiftUI

/// Generic "we just sent you an email — go confirm" waiting screen used for
/// both signup confirmation and password reset. Owns its own countdown
/// timer and resend state; the caller wires the actual network call via
/// `onResend`.
struct EmailWaitingView: View {
    let title: String
    let email: String
    let bodyCopy: String
    let onResend: () async throws -> Void

    private static let cooldownSeconds: Int = 60

    @Environment(\.dismiss) private var dismiss
    @State private var secondsRemaining: Int = EmailWaitingView.cooldownSeconds
    @State private var isResending = false
    @State private var resendError: String?
    @State private var didResendOnce = false

    private var canResend: Bool { secondsRemaining <= 0 && !isResending }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(AppColors.gold)
                    .padding(24)
                    .background(
                        Circle()
                            .fill(AppColors.gold.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(title)
                        .font(AppFonts.display(28))
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)

                    Text(bodyCopy)
                        .font(AppFonts.body(15))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Text("Sent to")
                        .font(AppFonts.bodyMedium(11))
                        .foregroundStyle(AppColors.dim)
                        .kerning(0.6)
                    Text(email)
                        .font(AppFonts.bodyBold(15))
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Button {
                        Task { await resend() }
                    } label: {
                        HStack(spacing: 8) {
                            if isResending {
                                ProgressView()
                                    .tint(AppColors.gold)
                            }
                            Text(resendButtonLabel)
                                .font(AppFonts.bodyBold(15))
                                .foregroundStyle(canResend ? AppColors.gold : AppColors.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canResend ? AppColors.gold.opacity(0.5) : AppColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canResend)

                    if didResendOnce, secondsRemaining > 0, resendError == nil {
                        Text("New email sent. Check your inbox.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.gold)
                    }

                    if let resendError {
                        Text(resendError)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                Text("Once you tap the link in the email, this screen will move on automatically.")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.dim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)
            }
        }
        .background(AppColors.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runCooldownTimer()
        }
    }

    private var resendButtonLabel: String {
        if isResending { return "Sending…" }
        if secondsRemaining > 0 {
            return "Resend email in \(secondsRemaining)s"
        }
        return "Resend email"
    }

    private func resend() async {
        guard canResend else { return }
        isResending = true
        resendError = nil
        defer { isResending = false }
        do {
            try await onResend()
            didResendOnce = true
            secondsRemaining = Self.cooldownSeconds
            await runCooldownTimer()
        } catch {
            resendError = error.localizedDescription
        }
    }

    private func runCooldownTimer() async {
        while secondsRemaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            secondsRemaining -= 1
        }
    }
}
