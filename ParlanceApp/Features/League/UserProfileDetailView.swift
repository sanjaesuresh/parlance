import SwiftUI

struct UserProfileDetailView: View {
    @StateObject private var socialService = SocialService()
    @State private var relationshipState: RelationshipState = .none
    @State private var isLoadingRelationship = true
    @State private var resolvedProfile: SocialProfile
    @State private var requestActionHaptic = false
    @State private var showUnfriendConfirm = false
    @State private var showBlockConfirm = false
    @State private var showReportSheet = false
    @State private var blockSuccessHaptic = false
    @Environment(\.dismiss) private var dismiss

    init(profile: SocialProfile) {
        _resolvedProfile = State(initialValue: profile)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    statsGrid
                    recentScoresCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Menu {
                            Button {
                                showReportSheet = true
                            } label: {
                                Label("Report user", systemImage: "exclamationmark.bubble")
                            }
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Block user", systemImage: "nosign")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppColors.sub)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("userProfileOverflowMenu")

                        Button("Done") { dismiss() }
                            .foregroundStyle(AppColors.gold)
                            .accessibilityIdentifier("userProfileDoneButton")
                    }
                }
            }
            .toolbarBackground(AppColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sensoryFeedback(.success, trigger: requestActionHaptic)
            .sensoryFeedback(.warning, trigger: blockSuccessHaptic)
            .confirmationDialog(
                "Unfriend \(resolvedProfile.displayName)?",
                isPresented: $showUnfriendConfirm,
                titleVisibility: .visible
            ) {
                Button("Unfriend", role: .destructive) {
                    guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                    requestActionHaptic.toggle()
                    Task {
                        try? await socialService.removeFriend(profileId)
                        relationshipState = .none
                    }
                }
                .accessibilityIdentifier("confirmUnfriendButton")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be removed from each other's friends lists. You can re-add them anytime.")
            }
            .confirmationDialog(
                "Block \(resolvedProfile.displayName)?",
                isPresented: $showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) {
                    guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                    blockSuccessHaptic.toggle()
                    Task {
                        try? await socialService.blockUser(profileId)
                        dismiss()
                    }
                }
                .accessibilityIdentifier("confirmBlockButton")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They won't be able to find you or send you friend requests. You can unblock them from Settings.")
            }
            .sheet(isPresented: $showReportSheet) {
                ReportUserSheet(
                    displayName: resolvedProfile.displayName,
                    onSubmit: { reason, details in
                        guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                        Task { try? await socialService.reportUser(profileId, reason: reason, details: details) }
                    }
                )
            }
            .task {
                guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                relationshipState = await socialService.relationshipState(for: profileId)
                isLoadingRelationship = false
                let scores = await socialService.fetchRecentScores(for: profileId)
                resolvedProfile = SocialProfile(
                    id: resolvedProfile.id,
                    displayName: resolvedProfile.displayName,
                    username: resolvedProfile.username,
                    avatarEmoji: resolvedProfile.avatarEmoji,
                    location: resolvedProfile.location,
                    occupation: resolvedProfile.occupation,
                    xp: resolvedProfile.xp,
                    weeklyXP: resolvedProfile.weeklyXP,
                    currentStreak: resolvedProfile.currentStreak,
                    avgScore: resolvedProfile.avgScore,
                    totalSessions: resolvedProfile.totalSessions,
                    rankLevel: resolvedProfile.rankLevel,
                    recentScores: scores
                )
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.gold.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle().stroke(AppColors.gold.opacity(0.5), lineWidth: 2)
                    )
                    .overlay(
                        Text(resolvedProfile.avatarEmoji)
                            .font(.system(size: 38))
                    )

                Text("LV \(resolvedProfile.rank.level)")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.gold)
                    .clipShape(Capsule())
                    .offset(x: 4, y: 4)
            }

            Text(resolvedProfile.displayName)
                .font(AppFonts.display(24))
                .foregroundStyle(AppColors.text)

            Text("@\(resolvedProfile.username)")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)

            Text(resolvedProfile.rank.name)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)

            HStack(spacing: 12) {
                if let location = resolvedProfile.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.dim)
                        Text(location)
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
                if let occupation = resolvedProfile.occupation {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.dim)
                        Text(occupation)
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }

            HStack(spacing: 8) {
                PillBadge(text: "\u{1F525} \(resolvedProfile.currentStreak)-day streak", color: AppColors.gold, small: true)

                let tier = LeagueTier.from(weeklyXP: resolvedProfile.weeklyXP)
                PillBadge(text: "\(tier.displayName) League", color: AppColors.purple, small: true)
            }

            if !isLoadingRelationship && relationshipState != .isSelf {
                relationshipButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Relationship Button

    @ViewBuilder
    private var relationshipButton: some View {
        switch relationshipState {
        case .none:
            Button("Add Friend") {
                guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                requestActionHaptic.toggle()
                Task {
                    try? await socialService.sendFriendRequest(to: profileId)
                    relationshipState = .pendingSent
                }
            }
            .font(AppFonts.bodyBold(13))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(AppColors.gold)
            .clipShape(Capsule())
            .accessibilityIdentifier("addFriendButton")

        case .pendingSent:
            Button("Cancel Request") {
                guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                requestActionHaptic.toggle()
                Task {
                    try? await socialService.cancelFriendRequest(to: profileId)
                    relationshipState = .none
                }
            }
            .font(AppFonts.bodyBold(13))
            .foregroundStyle(AppColors.sub)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(AppColors.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
            .accessibilityIdentifier("cancelRequestButton")

        case .pendingReceived:
            Button("Accept Request") {
                guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
                requestActionHaptic.toggle()
                Task {
                    try? await socialService.acceptRequestFrom(profileId)
                    relationshipState = .friends
                }
            }
            .font(AppFonts.bodyBold(13))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(AppColors.teal)
            .clipShape(Capsule())
            .accessibilityIdentifier("acceptRequestButton")

        case .friends:
            Button("Unfriend", role: .destructive) {
                showUnfriendConfirm = true
            }
            .font(AppFonts.bodyBold(13))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(AppColors.red)
            .clipShape(Capsule())
            .accessibilityIdentifier("unfriendButton")

        case .isSelf:
            EmptyView()
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        let statColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: statColumns, spacing: 10) {
            statCell(value: "\(resolvedProfile.totalSessions)", label: "Sessions")
            statCell(value: "\(resolvedProfile.avgScore)", label: "Avg Score")
            statCell(value: "\(resolvedProfile.currentStreak)", label: "Day Streak")
            statCell(value: "\(resolvedProfile.weeklyXP)", label: "Weekly XP")
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.gold)
            Text(label.uppercased())
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Recent Scores

    private var recentScoresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")

            if resolvedProfile.recentScores.isEmpty {
                Text("No sessions yet")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            } else {
                ForEach(Array(resolvedProfile.recentScores.enumerated()), id: \.offset) { index, score in
                    HStack {
                        Text("Session \(resolvedProfile.recentScores.count - index)")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)

                        Spacer()

                        Text("\(score)")
                            .font(AppFonts.display(18))
                            .foregroundStyle(scoreColor(score))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(scoreColor(score).opacity(0.5))
                            .frame(width: CGFloat(score), height: 6)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .cardStyle()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }
}

// MARK: - PublicProfileDetailView

struct PublicProfileDetailView: View {
    let profile: PublicProfile
    @State private var isAdding = false
    @State private var addError: String?
    @StateObject private var socialService = SocialService()

    var body: some View {
        VStack(spacing: 20) {
            Text(profile.avatarEmoji)
                .font(.system(size: 56))
                .frame(width: 96, height: 96)
                .background(AppColors.faint)
                .clipShape(Circle())

            Text("@\(profile.username)")
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)

            PillBadge(text: "\(profile.tier.displayName) League", color: profile.tier.color, small: true)

            Button {
                Task { await sendRequest() }
            } label: {
                Text(isAdding ? "Sending…" : "Add Friend")
                    .font(AppFonts.bodyBold(15))
                    .foregroundStyle(AppColors.onGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isAdding)
            .padding(.horizontal, 24)

            if let addError {
                Text(addError)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.red)
            }

            Text("Add as a friend to see their full profile, sessions, and stats.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
    }

    private func sendRequest() async {
        guard let userId = UUID(uuidString: profile.id) else { return }
        isAdding = true
        defer { isAdding = false }
        do {
            try await socialService.sendFriendRequest(to: userId)
        } catch {
            addError = "Couldn't send request. Try again."
        }
    }
}

// MARK: - ReportUserSheet

private struct ReportUserSheet: View {
    let displayName: String
    let onSubmit: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "Harassment"
    @State private var details = ""
    @State private var isSubmitted = false

    private let reasons = ["Harassment", "Spam", "Impersonation", "Inappropriate content", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Why are you reporting \(displayName)?")
                }

                Section {
                    TextField("Additional details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .font(AppFonts.body(15))
                } header: {
                    Text("Details")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.bg)
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.sub)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(selectedReason, trimmedDetails.isEmpty ? nil : trimmedDetails)
                        isSubmitted = true
                        dismiss()
                    }
                    .foregroundStyle(AppColors.gold)
                    .fontWeight(.semibold)
                    .disabled(isSubmitted)
                    .accessibilityIdentifier("reportSubmitButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
