import SwiftUI

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
    @State private var deleteAccountError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if !subscription.isPro {
                        Button {
                            dismiss()
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(AppColors.gold)
                                    .frame(width: 24)
                                Text("Upgrade to Pro")
                                    .font(AppFonts.body(14))
                                    .foregroundStyle(AppColors.gold)
                                Spacer()
                                Text("\u{203A}")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppColors.dim)
                            }
                            .padding(.vertical, 12)
                        }

                        Divider().background(AppColors.border)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.dailyReminderEnabled },
                        set: { viewModel.toggleDailyReminder($0) }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(AppColors.sub)
                                .frame(width: 24)
                            Text("Daily Reminder")
                                .font(AppFonts.body(14))
                                .foregroundStyle(AppColors.text)
                        }
                    }
                    .tint(AppColors.gold)
                    .padding(.vertical, 12)

                    Divider().background(AppColors.border)

                    Toggle(isOn: Binding(
                        get: { viewModel.soundEffectsEnabled },
                        set: { viewModel.toggleSoundEffects($0) }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(AppColors.sub)
                                .frame(width: 24)
                            Text("Sound Effects")
                                .font(AppFonts.body(14))
                                .foregroundStyle(AppColors.text)
                        }
                    }
                    .tint(AppColors.gold)
                    .padding(.vertical, 12)

                    Divider().background(AppColors.border)

                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(AppColors.sub)
                            .frame(width: 24)
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
                    .padding(.vertical, 12)

                    Divider().background(AppColors.border)

                    menuRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", isDestructive: true) {
                        showSignOutConfirmation = true
                    }
                    .accessibilityIdentifier("signOutButton")

                    Divider().background(AppColors.border)

                    menuRow(icon: "trash", title: "Reset All Data", isDestructive: true) {
                        viewModel.showResetConfirmation = true
                    }

                    Divider().background(AppColors.border)

                    menuRow(icon: "person.crop.circle.badge.minus", title: "Delete Account", isDestructive: true) {
                        showDeleteAccountConfirmation = true
                    }
                    .accessibilityIdentifier("deleteAccountButton")

                    Divider().background(AppColors.border)

                    menuRow(icon: "lock.shield", title: "Privacy Policy") {
                        safariURL = URL(string: "https://theparlance.app/privacy")
                        showSafari = true
                    }

                    Divider().background(AppColors.border)

                    menuRow(icon: "doc.text", title: "Terms of Service") {
                        safariURL = URL(string: "https://theparlance.app/terms")
                        showSafari = true
                    }

                    Divider().background(AppColors.border)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ABOUT YOUR DATA")
                            .font(AppFonts.bodyMedium(10))
                            .foregroundStyle(AppColors.dim)
                            .kerning(1.0)
                        Text("Recordings are transcribed on-device and immediately deleted. Your transcript is sent to our AI to generate coaching feedback. Pro subscribers' audio is also analyzed for emotion detection by our AI provider. All session data is stored locally on your device.")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
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
                    PersistenceService.shared.resetAllData()
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
    }

    private func menuRow(emoji: String = "", icon: String = "", title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if !emoji.isEmpty {
                    Text(emoji)
                        .frame(width: 24)
                } else if !icon.isEmpty {
                    Image(systemName: icon)
                        .foregroundStyle(isDestructive ? AppColors.red : AppColors.sub)
                        .frame(width: 24)
                }
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(isDestructive ? AppColors.red : AppColors.text)
                Spacer()
                Text("\u{203A}")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.dim)
            }
            .padding(.vertical, 12)
        }
    }
}
