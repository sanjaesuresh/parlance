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
    @State private var showRankSheet = false
    @State private var isSearching = false
    @State private var showMessageComposer = false
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

    /// Inputs for FriendsRankChip.
    /// The friends leaderboard does NOT include self, so we insert the current user
    /// client-side to compute rank and total. Returns nil only when auth is unavailable.
    private var friendsRankInputs: (rank: Int?, total: Int, weeklyXP: Int) {
        let myWeeklyXP = viewModel.weeklyXP(from: weekCache.sessions)
        let board = socialService.friendsLeaderboard
        guard !board.isEmpty else {
            // No friends yet — emit nil rank so the chip renders its empty state.
            return (rank: nil, total: 1, weeklyXP: myWeeklyXP)
        }
        // Insert self into the sorted board to find the correct 1-indexed rank.
        let myPosition = board.filter { $0.weeklyXP > myWeeklyXP }.count
        let rank = myPosition + 1
        let total = board.count + 1  // friends + self
        return (rank: rank, total: total, weeklyXP: myWeeklyXP)
    }

    /// Builds the merged + ranked entry list for the rank sheet by inserting the
    /// current user into the friends leaderboard and assigning 1-indexed ranks.
    /// Each entry's 24h rank delta is looked up against the local rank-history snapshot.
    private var rankedEntries: [FriendsRankSheet.Entry] {
        let myWeeklyXP = viewModel.weeklyXP(from: weekCache.sessions)
        let myId = authService.currentUserID ?? user?.supabaseUID ?? ""

        struct Row {
            let id: String
            let displayName: String
            let username: String
            let avatarEmoji: String
            let avatarUrl: String?
            let avatarUpdatedAt: Date?
            let weeklyXP: Int
            let isMe: Bool
        }

        var rows: [Row] = socialService.friendsLeaderboard.map { p in
            Row(
                id: p.id,
                displayName: p.displayName,
                username: p.username,
                avatarEmoji: p.avatarEmoji,
                avatarUrl: p.avatarUrl,
                avatarUpdatedAt: p.avatarUpdatedAt,
                weeklyXP: p.weeklyXP,
                isMe: false
            )
        }
        rows.append(Row(
            id: myId,
            displayName: user?.displayName ?? "You",
            username: user?.username ?? "you",
            avatarEmoji: user?.avatarEmoji ?? "🎤",
            avatarUrl: user?.avatarUrl,
            avatarUpdatedAt: user?.avatarUpdatedAt,
            weeklyXP: myWeeklyXP,
            isMe: true
        ))
        // Stable sort: higher weeklyXP first; self wins ties so the user sees themselves
        // promoted above an inactive friend at the same XP — matches the chip's headline.
        rows.sort { lhs, rhs in
            if lhs.weeklyXP != rhs.weeklyXP { return lhs.weeklyXP > rhs.weeklyXP }
            if lhs.isMe != rhs.isMe { return lhs.isMe }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return rows.enumerated().map { idx, r in
            let rank = idx + 1
            let delta = FriendsRankHistoryService.shared.delta(userId: r.id, currentRank: rank)
            return FriendsRankSheet.Entry(
                id: r.id,
                rank: rank,
                displayName: r.displayName,
                username: r.username,
                avatarEmoji: r.avatarEmoji,
                avatarUrl: r.avatarUrl,
                avatarUpdatedAt: r.avatarUpdatedAt,
                weeklyXP: r.weeklyXP,
                isMe: r.isMe,
                delta: delta
            )
        }
    }

    /// Snapshots the current ranking so the 24h rank-delta service has data to compare against.
    private func recordRankSnapshot() {
        let rankings = rankedEntries.map { (userId: $0.id, rank: $0.rank) }
        FriendsRankHistoryService.shared.record(rankings: rankings)
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
                                VStack(spacing: 10) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        leaderboardSkeletonRow
                                    }
                                }
                                .padding(14)
                                .cardStyle()
                            } else if searchResults.isEmpty {
                                noResultsView
                            } else {
                                searchResultsList
                            }
                        } else {
                            friendsRankChip
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
            .sheet(isPresented: $showRankSheet) {
                FriendsRankSheet(entries: rankedEntries)
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
                // Snapshot current rankings so the 24h delta has something to compare against later.
                recordRankSnapshot()
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
            Text("Compete and connect")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)
            HStack(spacing: 0) {
                Text("Social")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
                Text(".")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.gold)
            }
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
                    Text("Current league")
                        .font(AppFonts.bodyMedium(10))
                        .foregroundStyle(AppColors.sub)
                        .kerning(0.4)

                    HStack(spacing: 8) {
                        Image(systemName: "rosette")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tier.color)
                        Text("\(tier.displayName) League")
                            .font(AppFonts.display(24))
                            .foregroundStyle(AppColors.text)
                    }

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
                            .foregroundStyle(AppColors.text)
                    } else {
                        Text("Among friends")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                        Text("#\(userRank)")
                            .font(AppFonts.display(34))
                            .foregroundStyle(AppColors.text)
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
                            .foregroundStyle(AppColors.text)
                    }
                }
                ProgressBar(pct: progress, color: AppColors.gold, height: 6, label: "Tier progress")
            }
        }
        .padding(20)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 10) {
            tabButton(title: "Leaderboard", systemImage: "trophy.fill", tab: .leaderboard)
            tabButton(title: "Friends", systemImage: "person.2.fill", tab: .friends)
        }
    }

    private func tabButton(title: String, systemImage: String, tab: SocialTab) -> some View {
        let isSelected = selectedTab == tab
        let identifier = tab == .leaderboard ? "socialTab_leaderboard" : "socialTab_friends"
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(AppFonts.bodyBold(13))
            }
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
            GlobalLeaderboardSection(snapshot: snapshot) { entry in
                selectedSearchProfile = PublicProfile(
                    id: entry.id,
                    username: entry.username,
                    avatarEmoji: entry.avatarEmoji,
                    avatarUrl: entry.avatarUrl,
                    avatarUpdatedAt: entry.avatarUpdatedAt,
                    weeklyXP: entry.weeklyXP,
                    tier: entry.tier
                )
            }
        } else {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    leaderboardSkeletonRow
                }
            }
            .padding(14)
            .cardStyle()
        }
    }

    private var leaderboardSkeletonRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.card2)
                .frame(width: 32, height: 32)
                .shimmering()
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.card2)
                    .frame(width: 120, height: 10)
                    .shimmering()
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.card2)
                    .frame(width: 70, height: 8)
                    .shimmering()
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.card2)
                .frame(width: 40, height: 10)
                .shimmering()
        }
    }

    // MARK: - Share Profile Card

    private var shareProfileCard: some View {
        let username = user?.username ?? user?.displayName ?? "parlance user"
        let messageBody = "Been using this to practice speaking. You'd like it.\n\n\(AppURLs.home.absoluteString)"

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your profile link")
                        .font(AppFonts.bodyMedium(10))
                        .foregroundStyle(AppColors.dim)
                        .kerning(0.4)
                    Text("@\(username)")
                        .font(AppFonts.bodyBold(15))
                        .foregroundStyle(AppColors.text)
                }
                Spacer()
                inviteButton(messageBody: messageBody)
            }

            Text("Sends an iMessage with a link to Parlance.")
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
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(body: messageBody)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func inviteButton(messageBody: String) -> some View {
        let label = HStack(spacing: 5) {
            Image(systemName: "message.fill")
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

        if MessageComposeView.canSend {
            Button {
                showMessageComposer = true
            } label: {
                label
            }
            .accessibilityIdentifier("shareProfileButton")
        } else {
            // Devices without iMessage (no SIM, simulator, iPad without
            // Messages) fall back to the system share sheet so the entry
            // point is never dead.
            ShareLink(
                item: AppURLs.home,
                subject: Text("Join me on Parlance"),
                message: Text(messageBody)
            ) {
                label
            }
            .accessibilityIdentifier("shareProfileButton")
        }
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

    // MARK: - Friends Rank Chip

    private var friendsRankChip: some View {
        let inputs = friendsRankInputs
        return FriendsRankChip(
            rank: inputs.rank,
            total: inputs.total,
            weeklyXP: inputs.weeklyXP,
            avatarEmoji: user?.avatarEmoji ?? "🎤",
            avatarUrl: user?.avatarUrl,
            avatarUpdatedAt: user?.avatarUpdatedAt,
            displayName: user?.displayName ?? "You",
            onAddFriendsTapped: { isSearchFieldFocused = true },
            onRankTapped: {
                // Snapshot at open time so the first viewing also seeds history.
                recordRankSnapshot()
                showRankSheet = true
            }
        )
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
                AvatarView(
                    avatarUrl: profile.avatarUrl,
                    avatarEmoji: profile.avatarEmoji,
                    avatarUpdatedAt: profile.avatarUpdatedAt,
                    size: 42,
                    emojiFontSize: 20
                )

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
                VStack(spacing: 14) {
                    Image(systemName: "person.2.crop.square.stack")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.gold)
                    VStack(spacing: 4) {
                        Text("No friends yet.")
                            .font(AppFonts.display(18))
                            .foregroundStyle(AppColors.text)
                        Text("Find someone you know and compete weekly.")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.sub)
                            .multilineTextAlignment(.center)
                    }
                    PrimaryButton(title: "Find friends") {
                        isSearchFieldFocused = true
                    }
                    .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .cardStyle()
                .accessibilityIdentifier("friendsEmptyState")
            }
        }
    }

    private func friendRow(profile: SocialProfile) -> some View {
        Button { selectedProfile = profile } label: {
            HStack(spacing: 12) {
                AvatarView(
                    avatarUrl: profile.avatarUrl,
                    avatarEmoji: profile.avatarEmoji,
                    avatarUpdatedAt: profile.avatarUpdatedAt,
                    size: 40,
                    emojiFontSize: 18
                )

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
                                .foregroundStyle(AppColors.onAccent)
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
        let items: [(icon: String, label: String, hint: String?, value: String)] = [
            ("mic.fill", "Session completed", nil, "+\(AppConstants.baseXP) XP"),
            ("star.fill", "Score bonus", "+1 per point above 50", "up to +50"),
            ("flame.fill", "Streak bonus", "+5% per day, max 10 days", "up to +50%"),
            ("rosette", "Personal best", "Beat your top score in a mode", "+\(AppConstants.personalBestXPBonus) XP"),
            ("target", "Daily challenge", nil, "+\(AppConstants.dailyChallengeXP) XP"),
            ("arrow.up.right.circle.fill", "Difficulty bonus", "L6 / L8 / L10 = +20 / +40 / +60", "up to +60")
        ]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How XP Is Earned")

            VStack(spacing: 0) {
                ForEach(items, id: \.label) { item in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label)
                                .font(AppFonts.body(14))
                                .foregroundStyle(AppColors.text)
                            if let hint = item.hint {
                                Text(hint)
                                    .font(AppFonts.body(11))
                                    .foregroundStyle(AppColors.dim)
                            }
                        }
                        Spacer()
                        Text(item.value)
                            .font(AppFonts.bodyBold(13))
                            .foregroundStyle(AppColors.gold)
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .cardStyle()
    }
}
