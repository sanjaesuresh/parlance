import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var users: [User]
    @StateObject private var viewModel = ProgressViewModel()

    @State private var period: PeriodFilter = .month
    @State private var openSkill: MetricKey? = .structure
    @State private var standoutExpanded: Bool = false
    @State private var showAllSessions: Bool = false

    // MARK: - Mock data (DEBUG only, shown when no real sessions exist)

    #if DEBUG
    private static let mockSessions: [Session] = {
        func ago(_ n: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -n, to: .now)!
        }
        func make(mode: SessionMode, days: Int, score: Int, filler: Int, pace: Int, clarity: Int, structure: Int, vocab: Int, duration: TimeInterval, question: String, feedback: String?, xp: Int) -> Session {
            let s = Session(mode: mode, difficultyLevel: 5, duration: duration, transcript: "Mock.", overallScore: score, fillerCount: filler, paceScore: pace, clarityScore: clarity, structureScore: structure, vocabularyScore: vocab, question: question, aiCoachFeedback: feedback, xpEarned: xp, wasDailyChallenge: false)
            s.date = ago(days)
            return s
        }
        return [
            make(mode: .interview,   days: 0,  score: 82, filler: 2, pace: 8, clarity: 8, structure: 7, vocab: 9, duration: 95,  question: "Tell me about a time you overcame a significant challenge.",                feedback: "Solid STAR structure. Your example was specific and the outcome was clearly tied to your actions. Trim the preamble next time, the first 15 seconds added nothing.",              xp: 45),
            make(mode: .casual,      days: 1,  score: 75, filler: 4, pace: 7, clarity: 8, structure: 6, vocab: 8, duration: 78,  question: "Explain what you do for work to someone who's never heard of it.",         feedback: "Good energy. Your analogy landed well. Watch the filler words in the second half, they undermine the confident tone you built up early.",                                xp: 35),
            make(mode: .impromptu,   days: 2,  score: 68, filler: 6, pace: 6, clarity: 7, structure: 6, vocab: 7, duration: 62,  question: "You have 60 seconds: convince someone to try a new hobby.",                  feedback: "You had the right instinct to lead with emotion. The argument structure fell apart in the middle. Commit to one compelling reason rather than listing several weak ones.",          xp: 28),
            make(mode: .explanation, days: 3,  score: 88, filler: 1, pace: 9, clarity: 9, structure: 8, vocab: 9, duration: 110, question: "Explain how the internet works to a 10-year-old.",                          feedback: "Excellent. The postal service analogy was clear and memorable. Your pacing gave the listener time to follow along. The closing felt abrupt; a single wrap-up sentence would round this off.", xp: 52),
            make(mode: .interview,   days: 5,  score: 71, filler: 5, pace: 7, clarity: 7, structure: 6, vocab: 7, duration: 88,  question: "Describe a situation where you had to lead under pressure.",                feedback: "The story had real stakes. But you buried the outcome; in an interview context, the result is what the listener is waiting for. Get to it sooner.",                            xp: 32),
            make(mode: .casual,      days: 7,  score: 79, filler: 3, pace: 8, clarity: 8, structure: 7, vocab: 8, duration: 85,  question: "What's a book you'd recommend, and why?",                                    feedback: "Concise and personal. You gave a specific reason rather than a vague compliment, which made it credible. Slight overrun on pace at the end. Slow down when making your key point.", xp: 40),
            make(mode: .explanation, days: 8,  score: 90, filler: 1, pace: 9, clarity: 9, structure: 9, vocab: 9, duration: 105, question: "Walk me through how a vaccine works.",                                      feedback: "One of your strongest sessions. The layered explanation held together from start to finish. Vocabulary was precise without being jargon-heavy.",                                  xp: 58),
            make(mode: .impromptu,   days: 10, score: 74, filler: 5, pace: 7, clarity: 7, structure: 6, vocab: 7, duration: 71,  question: "Describe your ideal workday in under 2 minutes.",                            feedback: "Good instinct to anchor on values early. The middle section repeated the same point twice. Trim it. End on the outcome, not the process.",                                       xp: 33),
            make(mode: .interview,   days: 12, score: 65, filler: 8, pace: 6, clarity: 6, structure: 6, vocab: 7, duration: 92,  question: "Why do you want to work here?",                                              feedback: "The core answer was solid but the delivery was tentative. Filler words spiked when discussing culture. Prep that section more thoroughly. The closing line landed well.",     xp: 25),
            make(mode: .explanation, days: 14, score: 86, filler: 2, pace: 8, clarity: 9, structure: 8, vocab: 8, duration: 98,  question: "Explain compound interest to a teenager.",                                  feedback: "Strong analogy in the opening, the snowball image worked. Structure was clean: concept, example, implication. Minor rhythm issue in the middle, but overall very polished.",  xp: 50),
        ]
    }()
    #endif

    private var effectiveSessions: [Session] {
        #if DEBUG
        return sessions.isEmpty ? Self.mockSessions : sessions
        #else
        return sessions
        #endif
    }

    private var currentUser: User? { users.first }

    // MARK: - Derived data

    private var periodSessions: [Session] {
        viewModel.sessions(effectiveSessions, in: period)
    }

    private var aggregate: ProgressViewModel.PeriodAggregate {
        viewModel.aggregate(effectiveSessions, for: period)
    }

    private var skillTrends: [ProgressViewModel.SkillTrendItem] {
        viewModel.skillTrends(effectiveSessions, for: period)
    }

    private var skillCards: [ProgressViewModel.SkillCardModel] {
        viewModel.skillCards(effectiveSessions, for: period)
    }

    private var standout: Session? {
        viewModel.standout(effectiveSessions, in: period)
    }

    private var allTime: ProgressViewModel.AllTimeStats {
        viewModel.allTimeStats(effectiveSessions, user: currentUser)
    }

    private var coachBrief: ProgressViewModel.CoachBrief? {
        viewModel.coachBrief(for: period, aggregate: aggregate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(AppColors.bg)
            .navigationBarHidden(true)
        }
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
        sectionHeader(title: "Standout moment", meta: "Tap for breakdown", topPadding: 18)
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
            Text("Finish a session in this period to see your standout moment.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
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
            EmptyView()
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
            Text("No sessions yet — start one →")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
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
        if let coachBrief {
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
