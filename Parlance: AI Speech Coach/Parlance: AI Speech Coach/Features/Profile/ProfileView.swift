import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var users: [User]
    @Query(sort: \Achievement.id) private var achievements: [Achievement]
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSafari = false
    @State private var safariURL: URL?

    private var user: User? { users.first }

    private let achievementColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    xpSection
                    achievementGrid
                    settingsSection
                    menuSection
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadSettings() }
            .alert("Reset All Data", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) { viewModel.resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your sessions, XP, streaks, and achievements. This cannot be undone.")
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            if let user {
                Text(user.avatarEmoji)
                    .font(.system(size: 60))

                Text(user.displayName)
                    .font(AppFonts.bodyBold(22))
                    .foregroundStyle(AppColors.text)

                Text("Joined \(user.joinDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)

                PillBadge(text: "Rank \(user.rank.level) \u{00B7} \(user.rank.name)")

                HStack(spacing: 12) {
                    Text("\u{1F525} \(user.currentStreak)-day streak")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.gold)

                    Text("Best: \(user.longestStreak) days")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }
            }
        }
    }

    // MARK: - XP

    private var xpSection: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
    }

    // MARK: - Achievements

    private var achievementGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            LazyVGrid(columns: achievementColumns, spacing: 12) {
                ForEach(achievements, id: \.id) { achievement in
                    VStack(spacing: 6) {
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 24))
                            .foregroundStyle(achievement.isUnlocked ? AppColors.gold : AppColors.sub.opacity(0.4))

                        Text(achievement.name)
                            .font(AppFonts.bodyMedium(12))
                            .foregroundStyle(achievement.isUnlocked ? AppColors.text : AppColors.sub)
                            .multilineTextAlignment(.center)

                        if !achievement.isUnlocked && achievement.goal > 1 {
                            Text("\(achievement.progress)/\(achievement.goal)")
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.sub)
                        }

                        if achievement.isUnlocked, let date = achievement.unlockedDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.gold.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(achievement.isUnlocked ? AppColors.gold.opacity(0.3) : AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            Toggle(isOn: Binding(
                get: { viewModel.dailyReminderEnabled },
                set: { viewModel.toggleDailyReminder($0) }
            )) {
                Label("Daily Reminder", systemImage: "bell.fill")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)

            Toggle(isOn: Binding(
                get: { viewModel.soundEffectsEnabled },
                set: { viewModel.toggleSoundEffects($0) }
            )) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)

            Toggle(isOn: Binding(
                get: { viewModel.autoAdvanceEnabled },
                set: { viewModel.toggleAutoAdvance($0) }
            )) {
                Label("Auto-Advance", systemImage: "forward.fill")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)
        }
        .cardStyle()
    }

    // MARK: - Menu

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "lock.shield", title: "Privacy Policy") {
                safariURL = URL(string: "https://parlance.app/privacy")
                showSafari = true
            }

            Divider().background(AppColors.border)

            menuRow(icon: "doc.text", title: "Terms of Service") {
                safariURL = URL(string: "https://parlance.app/terms")
                showSafari = true
            }

            Divider().background(AppColors.border)

            menuRow(icon: "trash", title: "Reset All Data", isDestructive: true) {
                viewModel.showResetConfirmation = true
            }
        }
        .cardStyle()
    }

    private func menuRow(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(isDestructive ? AppColors.red : AppColors.sub)
                    .frame(width: 24)
                Text(title)
                    .font(AppFonts.body(14))
                    .foregroundStyle(isDestructive ? AppColors.red : AppColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.sub)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("Parlance")
                .font(AppFonts.bodyMedium(13))
                .foregroundStyle(AppColors.sub)
            Text("Version 1.0.0")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.sub.opacity(0.6))
        }
        .padding(.top, 8)
    }
}
