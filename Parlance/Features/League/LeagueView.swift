import SwiftUI
import SwiftData

struct LeagueView: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @Query private var users: [User]
    @StateObject private var viewModel = LeagueViewModel()
    @State private var selectedTab: SocialTab = .leaderboard
    @State private var friendSearchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var selectedProfile: SocialProfile?
    @State private var weekSessions: [Session] = []

    private enum SocialTab {
        case leaderboard, friends
    }

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    tierBannerCard
                    tabSelector

                    if selectedTab == .leaderboard {
                        zoneLegend
                        leaderboardList
                        howXPEarnedCard
                    } else {
                        friendsSearchSection
                        if !searchResults.isEmpty {
                            searchResultsList
                        } else if !friendSearchText.isEmpty {
                            noResultsView
                        } else {
                            friendsSuggestions
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                headerView
            }
            .sheet(item: $selectedProfile) { profile in
                UserProfileDetailView(profile: profile)
            }
            .onAppear {
                weekSessions = PersistenceService.shared.sessionsThisWeek()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("COMPETE & CONNECT")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(1.2)
            Text("Social")
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppColors.bg)
    }

    // MARK: - Tier Banner

    private var tierBannerCard: some View {
        let sessions = weekSessions
        let weeklyXP = viewModel.weeklyXP(from: sessions)
        let tier = LeagueTier.from(weeklyXP: weeklyXP)
        let nextTierIndex = LeagueTier.allCases.firstIndex(of: tier).map { $0 + 1 }
        let nextTier: LeagueTier? = {
            guard let idx = nextTierIndex, idx < LeagueTier.allCases.count else { return nil }
            return LeagueTier.allCases[idx]
        }()
        let progress: Double = {
            guard let nextXP = tier.xpForNextTier else { return 100 }
            let gained = weeklyXP - tier.minXP
            let needed = nextXP - tier.minXP
            return Double(gained) / Double(max(1, needed)) * 100
        }()
        // Calculate user's rank in leaderboard
        let userRank: Int = {
            let sorted = SocialProfile.weeklyLeaderboard
            let index = sorted.firstIndex(where: { $0.weeklyXP <= weeklyXP }) ?? sorted.count
            return index + 1
        }()

        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT LEAGUE")
                        .font(AppFonts.bodyMedium(10))
                        .foregroundStyle(AppColors.gold)
                        .kerning(1.0)

                    Text("\u{1F947} \(tier.displayName) League")
                        .font(AppFonts.display(24))
                        .foregroundStyle(AppColors.text)

                    Text(viewModel.timeUntilReset())
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your rank")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                    Text("#\(userRank)")
                        .font(AppFonts.display(34))
                        .foregroundStyle(AppColors.gold)
                }
            }

            VStack(spacing: 8) {
                if let nextTier = nextTier {
                    HStack {
                        Text("Progress to \(nextTier.displayName)")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                        Spacer()
                        Text("\(weeklyXP) / \(tier.xpForNextTier ?? weeklyXP) XP")
                            .font(AppFonts.bodyMedium(11))
                            .foregroundStyle(AppColors.gold)
                    }
                }
                ProgressBar(pct: progress, color: AppColors.gold, height: 6)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1A1400"), Color(hex: "#221A00")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.gold.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 10) {
            tabButton(title: "\u{1F3C6} Leaderboard", tab: .leaderboard)
            tabButton(title: "\u{1F465} Friends", tab: .friends)
        }
    }

    private func tabButton(title: String, tab: SocialTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(AppFonts.bodyMedium(13))
                .foregroundStyle(isSelected ? AppColors.gold : AppColors.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? AppColors.gold.opacity(0.15) : AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppColors.gold.opacity(0.5) : AppColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Zone Legend

    private var zoneLegend: some View {
        HStack(spacing: 8) {
            zonePill(emoji: "\u{1F53C}", label: "Top 3 Promote", color: AppColors.gold)
            zonePill(emoji: "\u{1F6E1}", label: "Safe", color: AppColors.teal)
            zonePill(emoji: "\u{1F53D}", label: "Bottom 3 Demote", color: AppColors.red)
        }
    }

    private func zonePill(emoji: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(emoji)
                .font(.system(size: 10))
            Text(label)
                .font(AppFonts.body(9))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Leaderboard

    private var leaderboardList: some View {
        let leaderboard = SocialProfile.weeklyLeaderboard
        let myWeeklyXP = viewModel.weeklyXP(from: weekSessions)

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "This Week")

            // Current user's row (highlighted)
            if let user {
                leaderboardRow(
                    rank: {
                        let index = leaderboard.firstIndex(where: { $0.weeklyXP <= myWeeklyXP }) ?? leaderboard.count
                        return index + 1
                    }(),
                    name: user.displayName,
                    emoji: user.avatarEmoji,
                    xp: myWeeklyXP,
                    isCurrentUser: true,
                    onTap: nil
                )
            }

            // Other users
            ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, profile in
                leaderboardRow(
                    rank: index + 1 + (myWeeklyXP > profile.weeklyXP ? 1 : 0),
                    name: profile.displayName,
                    emoji: profile.avatarEmoji,
                    xp: profile.weeklyXP,
                    isCurrentUser: false,
                    onTap: { selectedProfile = profile }
                )
            }
        }
    }

    private func leaderboardRow(rank: Int, name: String, emoji: String, xp: Int, isCurrentUser: Bool, onTap: (() -> Void)?) -> some View {
        let zoneColor: Color = rank <= 3 ? AppColors.gold : rank >= 10 ? AppColors.red : AppColors.text

        return Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Rank number
                Text("#\(rank)")
                    .font(AppFonts.bodyBold(14))
                    .foregroundStyle(zoneColor)
                    .frame(width: 32, alignment: .leading)

                // Avatar
                Text(emoji)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(isCurrentUser ? AppColors.gold.opacity(0.2) : AppColors.faint)
                    .clipShape(Circle())

                // Name
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(isCurrentUser ? AppColors.gold : AppColors.text)
                        if isCurrentUser {
                            Text("YOU")
                                .font(AppFonts.bodyBold(8))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppColors.gold)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Weekly XP
                Text("\(xp) XP")
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(AppColors.dim)

                if !isCurrentUser {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.dim)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCurrentUser ? AppColors.gold.opacity(0.08) : AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCurrentUser ? AppColors.gold.opacity(0.4) : AppColors.border, lineWidth: 1)
            )
        }
        .disabled(isCurrentUser)
    }

    // MARK: - Friends Search

    private var friendsSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Find Friends")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.dim)
                    .font(.system(size: 14))
                TextField("Search by username or name", text: $friendSearchText)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: friendSearchText) { _, newValue in
                        searchResults = SocialProfile.search(query: newValue)
                    }

                if !friendSearchText.isEmpty {
                    Button {
                        friendSearchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.dim)
                    }
                }
            }
            .padding(12)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            if let user, let username = user.username, !username.isEmpty {
                HStack(spacing: 4) {
                    Text("Your username:")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                    Text("@\(username)")
                        .font(AppFonts.bodyBold(11))
                        .foregroundStyle(AppColors.gold)
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)

            ForEach(searchResults) { profile in
                Button {
                    selectedProfile = profile
                } label: {
                    HStack(spacing: 12) {
                        Text(profile.avatarEmoji)
                            .font(.system(size: 20))
                            .frame(width: 42, height: 42)
                            .background(AppColors.faint)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(AppFonts.bodyMedium(14))
                                .foregroundStyle(AppColors.text)
                            HStack(spacing: 6) {
                                Text("@\(profile.username)")
                                    .font(AppFonts.body(12))
                                    .foregroundStyle(AppColors.sub)
                                if let location = profile.location {
                                    Text("\u{00B7}")
                                        .foregroundStyle(AppColors.dim)
                                    Text(location)
                                        .font(AppFonts.body(11))
                                        .foregroundStyle(AppColors.dim)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Avg \(profile.avgScore)")
                                .font(AppFonts.bodyBold(12))
                                .foregroundStyle(scoreColor(profile.avgScore))
                            Text("\u{1F525} \(profile.currentStreak)")
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.dim)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.dim)
                    }
                    .padding(12)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.sub)
            Text("No users found for \"\(friendSearchText)\"")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)

            ShareLink(item: URL(string: "https://apps.apple.com/app/parlance")!) {
                Text("Invite them to Parlance")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.gold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
    }

    // MARK: - Friends Suggestions

    private var friendsSuggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Suggested")

            ForEach(Array(SocialProfile.mockUsers.prefix(5))) { profile in
                Button {
                    selectedProfile = profile
                } label: {
                    HStack(spacing: 12) {
                        Text(profile.avatarEmoji)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(AppColors.faint)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(AppFonts.bodyMedium(13))
                                .foregroundStyle(AppColors.text)
                            Text("@\(profile.username)")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                        }

                        Spacer()

                        Button {
                            // Add friend action — placeholder for backend
                        } label: {
                            Text("Add")
                                .font(AppFonts.bodyBold(12))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppColors.gold)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
            }

            ShareLink(item: URL(string: "https://apps.apple.com/app/parlance")!) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                    Text("Invite Friends to Parlance")
                        .font(AppFonts.bodyMedium(13))
                }
                .foregroundStyle(AppColors.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.gold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - How XP Is Earned

    private var howXPEarnedCard: some View {
        let xpItems: [(emoji: String, label: String, xp: String)] = [
            ("\u{1F3A4}", "Session Completed", "+120 XP"),
            ("\u{1F4C5}", "Daily Streak", "+30 XP"),
            ("\u{1F4AF}", "Score 80+", "+50 bonus"),
            ("\u{1F3C6}", "Top 3 Finish", "+200 XP")
        ]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How XP Is Earned")

            ForEach(xpItems, id: \.label) { item in
                HStack {
                    Text(item.emoji)
                        .font(.system(size: 16))
                    Text(item.label)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text(item.xp)
                        .font(AppFonts.bodyBold(13))
                        .foregroundStyle(AppColors.gold)
                }
                .padding(.vertical, 2)
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }
}
