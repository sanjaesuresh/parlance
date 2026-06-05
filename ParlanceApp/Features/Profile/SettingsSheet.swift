import SwiftUI
import Supabase

struct SettingsSheet: View {
    @Binding var showPaywall: Bool
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject private var subscription: SubscriptionService
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isStartingPasswordReset = false
    @State private var passwordResetError: String?
    @State private var deleteAccountError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !subscription.isPro {
                        proUpgradeCard
                            .padding(.top, 4)
                    }

                    settingsSection("Preferences") {
                        groupedCard {
                            toggleRow(
                                icon: "bell.fill",
                                title: "Daily Reminder",
                                isOn: Binding(
                                    get: { viewModel.dailyReminderEnabled },
                                    set: { viewModel.toggleDailyReminder($0) }
                                )
                            )
                            rowDivider
                            toggleRow(
                                icon: "speaker.wave.2.fill",
                                title: "Sound Effects",
                                isOn: Binding(
                                    get: { viewModel.soundEffectsEnabled },
                                    set: { viewModel.toggleSoundEffects($0) }
                                )
                            )
                            rowDivider
                            appearanceRow
                        }
                    }

                    settingsSection("Account") {
                        groupedCard {
                            destructiveRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                accessibilityID: "signOutButton"
                            ) {
                                showSignOutConfirmation = true
                            }
                            rowDivider
                            destructiveRow(
                                icon: "trash",
                                title: "Reset All Data"
                            ) {
                                viewModel.showResetConfirmation = true
                            }
                            if authService.hasPasswordIdentity {
                                rowDivider
                                navRow(
                                    icon: "key.fill",
                                    title: isStartingPasswordReset ? "Sending email…" : "Change Password"
                                ) {
                                    Task { await startPasswordReset() }
                                }
                                .disabled(isStartingPasswordReset)
                            }
                            rowDivider
                            destructiveRow(
                                icon: "person.crop.circle.badge.minus",
                                title: "Delete Account",
                                accessibilityID: "deleteAccountButton"
                            ) {
                                showDeleteAccountConfirmation = true
                            }
                        }
                    }

                    settingsSection("Legal") {
                        groupedCard {
                            linkRow(icon: "lock.shield", title: "Privacy Policy") {
                                safariURL = AppURLs.privacy
                                showSafari = true
                            }
                        }
                    }

                    finePrintBlock
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.gold)
                }
            }
        }
        .presentationDetents([.large])
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authService.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do {
                        try await authService.deleteAccount()
                    } catch {
                        deleteAccountError = "Could not delete your account. Please check your connection and try again."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
        }
        .alert("Deletion Failed", isPresented: Binding(
            get: { deleteAccountError != nil },
            set: { if !$0 { deleteAccountError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountError ?? "")
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .alert("Couldn't send email", isPresented: Binding(
            get: { passwordResetError != nil },
            set: { if !$0 { passwordResetError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(passwordResetError ?? "")
        }
    }

    /// Triggered by the Change Password row. Sends a password-reset email to
    /// the signed-in user's address; on success, dismisses Settings so the
    /// root waiting sheet (driven by `authService.pendingResetEmail`) can
    /// take over. The actual password update only happens AFTER the user
    /// taps the email link — Supabase's `.passwordRecovery` event then
    /// presents `ChangePasswordSheet` from ContentView.
    private func startPasswordReset() async {
        guard let email = authService.currentUser?.email, !email.isEmpty else {
            passwordResetError = "We couldn't find an email on your account. Sign out and back in, then try again."
            return
        }
        isStartingPasswordReset = true
        defer { isStartingPasswordReset = false }
        do {
            try await authService.sendPasswordReset(email: email)
            dismiss()
        } catch {
            passwordResetError = error.localizedDescription
        }
    }

    // MARK: - Pro upgrade hero

    private var proUpgradeCard: some View {
        Button {
            dismiss()
            showPaywall = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.gold)
                        .frame(width: 44, height: 44)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.onGold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Pro")
                        .font(AppFonts.display(18))
                        .foregroundStyle(AppColors.text)
                    Text("Advanced modes, deeper feedback, vocal tone.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("Unlock")
                    .font(AppFonts.bodyBold(11))
                    .kerning(0.6)
                    .foregroundStyle(AppColors.onGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.gold)
                    .clipShape(Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.challengeGradientStart, AppColors.challengeGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Pro. Advanced modes, deeper feedback, vocal tone.")
    }

    // MARK: - Editorial section header

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
                .padding(.bottom, 18)
            Text(title)
                .font(AppFonts.display(18))
                .foregroundStyle(AppColors.text)
                .padding(.bottom, 12)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Grouped card stack

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(height: 1)
            .padding(.leading, 52)
    }

    // MARK: - Rows

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.sub)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)
            Toggle(isOn: isOn) {
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var appearanceRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 15))
                .foregroundStyle(AppColors.sub)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)
            Text("Appearance")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.text)
            Spacer()
            Picker("Appearance", selection: $appThemeRaw) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Text(theme.displayName).tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func destructiveRow(icon: String, title: String, accessibilityID: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.red)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "")
    }

    private func navRow(icon: String, title: String, accessibilityID: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.sub)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "")
    }

    private func linkRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.sub)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fine print

    private var finePrintBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            Text("Fine print")
                .font(AppFonts.bodyMedium(10))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your data")
                    .font(AppFonts.bodyBold(11))
                    .foregroundStyle(AppColors.sub)
                Text("Your recording is transcribed by Apple Speech Recognition — on-device when your language supports it, otherwise via Apple's servers — and then deleted from your device. The transcript is sent over an encrypted connection through our Cloudflare Worker proxy to Google Gemini, which generates your coaching feedback. On Pro, a short audio clip is also sent through the same proxy to Hume AI for vocal tone analysis and is not retained. Session data (scores, transcripts, XP) is stored locally on your device; your profile and aggregate stats sync to Supabase so you can use Parlance across devices.")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("About the AI")
                    .font(AppFonts.bodyBold(11))
                    .foregroundStyle(AppColors.sub)
                Text("AI scores and feedback are for practice only. They aren't a substitute for professional coaching, therapy, or medical advice.")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
