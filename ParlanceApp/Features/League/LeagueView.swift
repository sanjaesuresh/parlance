import SwiftUI
import SwiftData

struct LeagueView: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @Query private var users: [User]
    @StateObject private var viewModel = LeagueViewModel()
    @StateObject private var socialService = SocialService()
    @EnvironmentObject private var weekCache: SessionWeekCache
    @EnvironmentObject private var authService: AuthService
    @Binding var openFriendRequests: Bool
    @State private var selectedTab: SocialTab = .leaderboard
    @State private var friendSearchText = ""
    @State private var searchResults: [PublicProfile] = []
    @State private var selectedProfile: SocialProfile?
    @State private var selectedSearchProfile: PublicProfile?
    @State private var showRequestsSheet = false
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    init(openFriendRequests: Binding<Bool> = .constant(false)) {
        self._openFriendRequests = openFriendRequests
    }

    private enum SocialTab {
        case leaderboard, friends
    }

    private var user: User? {
        users.first { $0.supabaseUID == authService.currentUserID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    tierBannerCard
                    tabSelector

                    if selectedTab == .leaderboard {
                        promotionStatusBar
                        globalLeaderboardSection
                        howXPEarnedCard
                    } else {
                        if socialService.pendingRequestCount > 0 {
                            pendingRequestsBanner
                        }
                        shareProfileCard
                        friendsSearchSection
                        if !friendSearchText.isEmpty {
                            if isSearching {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if searchResults.isEmpty {
                                noResultsView
                            } else {
                                searchResultsList
                            }
                        } else {
                            if !socialService.friendsLeaderboard.isEmpty {
                                addedFriendsSection
                            }
                            if !socialService.friendActivity.isEmpty {
                                activityFeedSection
                            }
                            friendsSuggestions
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .scrollDismissesKeyboard(.interactively)
            // Tap outside the search field dismisses the keyboard.
            .simultaneousGesture(TapGesture().onEnded {
                if isSearchFieldFocused {
                    isSearchFieldFocused = false
                }
            })
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                headerView
            }
            .sheet(item: $selectedProfile, onDismiss: {
                // Clear focus so the keyboard doesn't reappear over the tab bar
                isSearchFieldFocused = false
            }) { profile in
                UserProfileDetailView(profile: profile)
            }
            .sheet(item: $selectedSearchProfile) { profile in
                PublicProfileDetailView(profile: profile)
            }
            .sheet(isPresented: $showRequestsSheet, onDismiss: {
                openFriendRequests = false
                Task {
                    await socialService.refreshPendingRequestCount()
                    // Refresh leaderboard so newly accepted friends appear without
                    // requiring the user to leave and re-enter the tab.
                    await socialService.fetchFriendsLeaderboard()
                }
            }) {
                FriendRequestsSheet(socialService: socialService)
            }
            .task {
                await socialService.fetchFriendsLeaderboard()
                await socialService.fetchGlobalLeaderboard()
                await socialService.fetchFriendActivity()
                await socialService.refreshPendingRequestCount()
            }
            .onChange(of: openFriendRequests) { _, shouldOpen in
                if shouldOpen {
                    selectedTab = .friends
                    showRequestsSheet = true
                    // openFriendRequests is reset in onDismiss to survive cold-launch
                    // auth flow transitions where this view may be transiently replaced.
                }
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
        let sessions = weekCache.sessions
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
        let userRank: Int = {
            let sorted = socialService.friendsLeaderboard
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

                    Text(viewModel.countdownText)
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if selectedTab == .leaderboard, let me = socialService.globalLeaderboard?.me {
                        Text("Global rank")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                        Text("#\(me.rank)")
                            .font(AppFonts.display(34))
                            .foregroundStyle(AppColors.gold)
                    } else {
                        Text("Among friends")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                        Text("#\(userRank)")
                            .font(AppFonts.display(34))
                            .foregroundStyle(AppColors.gold)
                    }
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
                ProgressBar(pct: progress, color: AppColors.gold, height: 6, label: "Tier progress")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColors.leagueBannerStart, AppColors.leagueBannerEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
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
        let identifier = tab == .leaderboard ? "socialTab_leaderboard" : "socialTab_friends"
        return Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(AppFonts.bodyBold(13))
                .foregroundStyle(isSelected ? AppColors.onGold : AppColors.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isSelected ? AppColors.gold : AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                )
        }
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Leaderboard Tab Sections

    private var promotionStatusBar: some View {
        let weeklyXP = viewModel.weeklyXP(from: weekCache.sessions)
        let tier = LeagueTier.from(weeklyXP: weeklyXP)
        let secondsToReset = viewModel.secondsUntilReset()
        let status = LeagueViewModel.promotionStatus(
            weeklyXP: weeklyXP,
            tier: tier,
            secondsToReset: secondsToReset
        )
        return PromotionStatusPill(status: status)
    }

    @ViewBuilder
    private var globalLeaderboardSection: some View {
        if let snapshot = socialService.globalLeaderboard {
            GlobalLeaderboardSection(snapshot: snapshot)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading leaderboard…")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .cardStyle()
        }
    }

    // MARK: - Share Profile Card

    private var shareProfileCard: some View {
        let username = user?.username ?? user?.displayName ?? "parlance user"
        let inviteURL = URL(string: "https://theparlance.app/invite?user=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)")!

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR PROFILE LINK")
                        .font(AppFonts.bodyMedium(10))
                        .foregroundStyle(AppColors.dim)
                        .kerning(1.0)
                    Text("@\(username)")
                        .font(AppFonts.bodyBold(15))
                        .foregroundStyle(AppColors.gold)
                }
                Spacer()
                ShareLink(
                    item: inviteURL,
                    subject: Text("Join me on Parlance"),
                    message: Text("I'm practicing public speaking on Parlance — join me! @\(username)")
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("Invite")
                            .font(AppFonts.bodyMedium(13))
                    }
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.gold.opacity(0.4), lineWidth: 1))
                }
                .accessibilityIdentifier("shareProfileButton")
            }

            Text("Friends without the app will be taken to download it.")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
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
                    .focused($isSearchFieldFocused)
                    .accessibilityIdentifier("friendSearchField")
                    .onChange(of: friendSearchText) { _, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            isSearching = false
                        } else {
                            isSearching = true
                            Task {
                                searchResults = await socialService.searchUsers(query: newValue)
                                isSearching = false
                            }
                        }
                    }

                if !friendSearchText.isEmpty {
                    Button {
                        friendSearchText = ""
                        searchResults = []
                        isSearchFieldFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.dim)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityIdentifier("friendSearchClearButton")
                }
            }
            .padding(12)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Added Friends

    private var addedFriendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "My Friends")

            ForEach(socialService.friendsLeaderboard) { profile in
                friendRow(profile: profile)
            }
        }
    }

    // MARK: - Friend Activity Feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Friend Activity")
            ForEach(socialService.friendActivity) { event in
                ActivityFeedRow(event: event)
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
                searchResultRow(profile: profile)
            }
        }
    }

    private func searchResultRow(profile: PublicProfile) -> some View {
        let identifier = "searchResult_\(profile.username)"
        return Button { selectedSearchProfile = profile } label: {
            HStack(spacing: 12) {
                Text(profile.avatarEmoji)
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(AppColors.faint)
                    .clipShape(Circle())

                Text("@\(profile.username)")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)

                Spacer()

                Text(profile.tier.displayName)
                    .font(AppFonts.bodyBold(11))
                    .foregroundStyle(profile.tier.color)
            }
        }
        .padding(12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityIdentifier(identifier)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.sub)
            Text("No users found for \"\(friendSearchText)\"")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
            Text("Ask your friend to share their username so you can search for them.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
        .accessibilityIdentifier("searchNoResultsState")
    }

    // MARK: - Friends Suggestions

    private var friendsSuggestions: some View {
        Group {
            if socialService.friendsLeaderboard.isEmpty {
                VStack(spacing: 8) {
                    Text("No friends yet. Search for friends above to get started.")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .cardStyle()
                .accessibilityIdentifier("friendsEmptyState")
            }
        }
    }

    private func friendRow(profile: SocialProfile) -> some View {
        Button { selectedProfile = profile } label: {
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
            }
        }
        .padding(10)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityIdentifier("friendRow_\(profile.username)")
    }

    // MARK: - Pending Requests Banner

    private var pendingRequestsBanner: some View {
        Button {
            showRequestsSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.gold)
                    Circle()
                        .fill(AppColors.red)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text("\(socialService.pendingRequestCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 6, y: -6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(socialService.pendingRequestCount) Friend \(socialService.pendingRequestCount == 1 ? "Request" : "Requests")")
                        .font(AppFonts.bodyBold(14))
                        .foregroundStyle(AppColors.text)
                    Text("Tap to review")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.dim)
            }
            .padding(14)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(AppColors.gold.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pendingRequestsBanner")
    }

    // MARK: - How XP Is Earned

    private var howXPEarnedCard: some View {
        let xpItems: [(emoji: String, label: String, xp: String)] = [
            ("\u{1F3A4}", "Session Completed", "+\(AppConstants.baseXP) XP"),
            ("\u{1F4C5}", "Daily Challenge", "+\(AppConstants.dailyChallengeXP) XP bonus"),
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
}
