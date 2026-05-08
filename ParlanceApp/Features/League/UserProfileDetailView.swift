import SwiftUI

struct UserProfileDetailView: View {
    @StateObject private var socialService = SocialService()
    @State private var relationshipState: RelationshipState = .none
    @State private var isLoadingRelationship = true
    @State private var resolvedProfile: SocialProfile
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
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.gold)
                }
            }
            .toolbarBackground(AppColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

        case .pendingSent:
            Text("Request Sent")
                .font(AppFonts.bodyBold(13))
                .foregroundStyle(AppColors.sub)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(AppColors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))

        case .pendingReceived:
            Button("Accept Request") {
                guard let profileId = UUID(uuidString: resolvedProfile.id) else { return }
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

        case .friends:
            Text("Friends")
                .font(AppFonts.bodyBold(13))
                .foregroundStyle(AppColors.teal)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(AppColors.teal.opacity(0.12))
                .clipShape(Capsule())

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
