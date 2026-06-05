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
    @State private var isRestoringPurchases = false
    @State private var restoreMessage: String?
    @State private var deleteAccountError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    settingsSection("Subscription") {
                        groupedCard {
                            if subscription.isPro {
                                proStatusRow
                                rowDivider
                                navRow(
                                    icon: "crown.fill",
                                    title: "Manage Subscription"
                                ) {
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                rowDivider
                                navRow(
                                    icon: "arrow.clockwise",
                                    title: isRestoringPurchases ? "Restoring…" : "Restore Purchases"
                                ) {
                                    Task { await restorePurchases() }
                                }
                                .disabled(isRestoringPurchases)
                            } else {
                                upgradeRow
                            }
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
        .alert("Restore Purchases", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    /// Triggered by the Restore Purchases row. Asks StoreKit to re-sync
    /// the user's transactions from Apple, then refreshes `isPro` from the
    /// updated entitlement cache. The success message is best-effort — if
    /// `AppStore.sync()` finds nothing to restore, isPro stays false and we
    /// say so; if it finds Pro, the row disappears (replaced by Manage).
    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        let wasPro = subscription.isPro
        await subscription.restorePurchases()
        if subscription.isPro {
            restoreMessage = wasPro
                ? "You're already subscribed to Parlance Pro."
                : "Welcome back to Parlance Pro."
        } else {
            restoreMessage = "No active subscription found on this Apple ID."
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

    // MARK: - Upgrade row (non-Pro)

    /// Single row in the Subscription section that opens the paywall for
    /// users who aren't subscribed yet. Apple's required Restore Purchases
    /// affordance for non-subscribers lives on the paywall itself, so this
    /// row is the only Subscription affordance non-Pro users need here.
    private var upgradeRow: some View {
        Button {
            dismiss()
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 28, height: 22, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parlance Pro")
                        .font(AppFonts.bodyBold(14))
                        .foregroundStyle(AppColors.text)
                    Text("Advanced modes, tone analysis, unlimited sessions.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Parlance Pro. Advanced modes, tone analysis, unlimited sessions.")
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
            .padding(.leading, 58)
    }

    // MARK: - Rows

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.sub)
                .frame(width: 28, height: 22, alignment: .center)
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
                .frame(width: 28, height: 22, alignment: .center)
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
                    .frame(width: 28, height: 22, alignment: .center)
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

    private var proStatusRow: some View {
        Button {
            dismiss()
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 28, height: 22, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parlance Pro")
                        .font(AppFonts.bodyBold(14))
                        .foregroundStyle(AppColors.text)
                    if let exp = subscription.expirationDate {
                        Text("Renews \(exp, format: .dateTime.month(.abbreviated).day().year())")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.dim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Parlance Pro. View benefits.")
    }

    private func navRow(icon: String, title: String, accessibilityID: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.sub)
                    .frame(width: 28, height: 22, alignment: .center)
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
                    .frame(width: 28, height: 22, alignment: .center)
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
