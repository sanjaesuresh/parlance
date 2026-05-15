import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var users: [User]
    @StateObject private var viewModel = ProgressViewModel()
    @StateObject private var briefStore = CoachBriefStore()
    @EnvironmentObject private var subscription: SubscriptionService

    @State private var period: PeriodFilter = .month
    @State private var openSkill: MetricKey? = .structure
    @State private var standoutExpanded: Bool = false
    @State private var showAllSessions: Bool = false
    @State private var isRefreshingBrief: Bool = false

    private var currentUser: User? { users.first }

    // MARK: - Derived data

    private var periodSessions: [Session] {
        viewModel.sessions(sessions, in: period)
    }

    private var aggregate: ProgressViewModel.PeriodAggregate {
        viewModel.aggregate(sessions, for: period)
    }

    private var skillTrends: [ProgressViewModel.SkillTrendItem] {
        viewModel.skillTrends(sessions, for: period)
    }

    private var skillCards: [ProgressViewModel.SkillCardModel] {
        viewModel.skillCards(sessions, for: period)
    }

    private var standout: Session? {
        viewModel.standout(sessions, in: period)
    }

    private var allTime: ProgressViewModel.AllTimeStats {
        viewModel.allTimeStats(sessions, user: currentUser)
    }

    private var coachBrief: ProgressViewModel.CoachBrief? {
        viewModel.coachBrief(for: period, aggregate: aggregate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
                    firstLaunchPrimer
                } else {
                    VStack(spacing: 0) {
                        header
                        ProgressSegmentedControl(selection: $period)
                            .padding(.top, 18)
                        StatsStripView(aggregate: aggregate)
                            .padding(.top, 18)
                        standoutSection
                        skillsSection
                        recentSessionsSection
                        coachBriefSection
                        AllTimeStatsCard(stats: allTime)
                            .padding(.top, 22)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppColors.bg)
            .navigationBarHidden(true)
            .refreshable {
                await refreshBrief(manual: true)
            }
            .task {
                if briefStore.shouldAutoRefresh() {
                    await refreshBrief(manual: false)
                }
            }
        }
    }

    // MARK: - Server-side coach brief

    private func refreshBrief(manual: Bool) async {
        if manual, !briefStore.canManuallyRefresh() { return }
        guard !isRefreshingBrief else { return }
        isRefreshingBrief = true
        defer { isRefreshingBrief = false }

        guard let payload = WeeklyBriefAggregator.build(
            sessions: sessions,
            user: currentUser,
            isPro: subscription.isPro
        ) else {
            briefStore.markAttempt()
            return
        }

        do {
            let brief = try await WeeklyBriefClient.fetch(payload: payload)
            briefStore.save(brief, manual: manual)
        } catch {
            briefStore.markAttempt()
            #if DEBUG
            print("[ProgressTab] weekly-brief refresh failed:", error)
            #endif
        }
    }

    // MARK: - First-launch primer (zero lifetime sessions)

    private var firstLaunchPrimer: some View {
        VStack(spacing: 0) {
            header

            ProgressEmptyHeroCard {
                DeepLinkRouter.shared.selectedTab = 0
            }
            .padding(.top, 22)

            emptyPreviewSection(
                title: "Standout moment",
                description: "Your best session of the period — score, prompt, and a snippet from your transcript."
            )

            emptyPreviewSection(
                title: "Skills",
                description: "Fillers, pace, clarity, structure, vocabulary, persuasion. Tracked across modes and surfaced over time."
            )

            emptyPreviewSection(
                title: "Recent sessions",
                description: "Every session lives here. Tap one to revisit the transcript, score breakdown, and coach feedback."
            )

            emptyPreviewSection(
                title: "All-time stats",
                description: "Sessions, total minutes, current streak, average score."
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func emptyPreviewSection(title: String, description: String) -> some View {
        sectionHeader(title: title, meta: nil, topPadding: 18)
            .padding(.top, 18)
        ProgressEmptyPreviewCard(description: description)
            .padding(.top, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR JOURNEY")
                .font(AppFonts.bodyMedium(10))
                .kerning(1.4)
                .foregroundStyle(AppColors.dim)
            Text("Progress")
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.text)
                .padding(.top, 4)
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Standout

    @ViewBuilder
    private var standoutSection: some View {
        sectionHeader(title: "Standout moment", meta: nil, topPadding: 18)
            .padding(.top, 18)

        if let standout {
            StandoutMomentCard(
                session: standout,
                isExpanded: standoutExpanded,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.30)) {
                        standoutExpanded.toggle()
                    }
                }
            )
            .padding(.top, 12)
        } else {
            ProgressEmptyPreviewCard(
                description: "Finish a session in this period and your standout moment lands here."
            )
            .padding(.top, 12)
        }
    }

    // MARK: - Skills

    @ViewBuilder
    private var skillsSection: some View {
        sectionHeader(title: "Skills", meta: nil, topPadding: 18)
            .padding(.top, 18)

        SkillTrendChart(trends: skillTrends)
            .padding(.top, 12)

        if skillCards.isEmpty {
            ProgressEmptyPreviewCard(
                description: "Record a session in this period to start tracking how each skill is moving."
            )
            .padding(.top, 12)
        } else {
            VStack(spacing: 10) {
                ForEach(skillCards) { card in
                    SkillCardView(
                        card: card,
                        isOpen: openSkill == card.key,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                openSkill = (openSkill == card.key) ? nil : card.key
                            }
                        }
                    )
                }
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Recent sessions

    @ViewBuilder
    private var recentSessionsSection: some View {
        let recent = Array(periodSessions.prefix(5))

        sectionHeader(
            title: "Recent sessions",
            meta: "\(periodSessions.count) in this period",
            topPadding: 18
        )
        .padding(.top, 18)

        if recent.isEmpty {
            ProgressEmptyPreviewCard(
                description: "No sessions in this period yet. Try a different range, or start one from Home."
            )
            .padding(.top, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, session in
                    RecentSessionRow(session: session, isLast: idx == recent.count - 1)
                }
            }
            .padding(.top, 4)

            if periodSessions.count > recent.count {
                viewAllPill(total: periodSessions.count)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func viewAllPill(total: Int) -> some View {
        Button {
            showAllSessions = true
        } label: {
            HStack(spacing: 8) {
                Text("View all sessions")
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(AppColors.gold)
                Text("· \(total)")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.gold.opacity(0.85))
            }
            .padding(.vertical, 9)
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .background(AppColors.card)
            .overlay(
                Capsule()
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View all \(total) sessions")
    }

    // MARK: - Coach brief

    @ViewBuilder
    private var coachBriefSection: some View {
        if let serverBrief = briefStore.latest {
            CoachBriefView(brief: ProgressViewModel.CoachBrief(
                body: serverBrief.brief,
                signature: "— Updated \(serverBrief.generatedAt.formatted(.dateTime.weekday().hour().minute()))",
                positiveHighlights: serverBrief.highlights.filter { $0.kind == "positive" }.map(\.phrase),
                negativeHighlights: serverBrief.highlights.filter { $0.kind == "negative" }.map(\.phrase)
            ))
            .padding(.top, 28)
        } else if let coachBrief {
            CoachBriefView(brief: coachBrief)
                .padding(.top, 28)
        }
    }

    // MARK: - Editorial section header

    private func sectionHeader(title: String, meta: String?, topPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppFonts.display(18))
                    .foregroundStyle(AppColors.text)
                Spacer()
                if let meta {
                    Text(meta)
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                }
            }
            .padding(.top, 22)
            .padding(.bottom, 12)
        }
    }
}
