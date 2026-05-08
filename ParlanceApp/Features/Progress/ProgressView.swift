import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var achievements: [Achievement]
    @StateObject private var viewModel = ProgressViewModel()
    @EnvironmentObject private var weekCache: SessionWeekCache

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
            make(mode: .interview, days: 0, score: 82, filler: 2, pace: 8, clarity: 8, structure: 7, vocab: 9, duration: 95, question: "Tell me about a time you overcame a significant challenge.", feedback: "Solid STAR structure. Your example was specific and the outcome was clearly tied to your actions. Trim the preamble next time — the first 15 seconds added nothing.", xp: 45),
            make(mode: .casual, days: 1, score: 75, filler: 4, pace: 7, clarity: 8, structure: 6, vocab: 8, duration: 78, question: "Explain what you do for work to someone who's never heard of it.", feedback: "Good energy. Your analogy landed well. Watch the filler words in the second half — they undermine the confident tone you built up early.", xp: 35),
            make(mode: .impromptu, days: 2, score: 68, filler: 6, pace: 6, clarity: 7, structure: 6, vocab: 7, duration: 62, question: "You have 60 seconds: convince someone to try a new hobby.", feedback: "You had the right instinct to lead with emotion. The argument structure fell apart in the middle — commit to one compelling reason rather than listing several weak ones.", xp: 28),
            make(mode: .explanation, days: 3, score: 88, filler: 1, pace: 9, clarity: 9, structure: 8, vocab: 9, duration: 110, question: "Explain how the internet works to a 10-year-old.", feedback: "Excellent. The postal service analogy was clear and memorable. Your pacing gave the listener time to follow along. The closing felt abrupt — a single wrap-up sentence would round this off.", xp: 52),
            make(mode: .interview, days: 5, score: 71, filler: 5, pace: 7, clarity: 7, structure: 6, vocab: 7, duration: 88, question: "Describe a situation where you had to lead under pressure.", feedback: "The story had real stakes. But you buried the outcome — in an interview context, the result is what the listener is waiting for. Get to it sooner.", xp: 32),
            make(mode: .casual, days: 7, score: 79, filler: 3, pace: 8, clarity: 8, structure: 7, vocab: 8, duration: 85, question: "What's a book you'd recommend, and why?", feedback: "Concise and personal. You gave a specific reason rather than a vague compliment, which made it credible. Slight overrun on pace at the end — slow down when making your key point.", xp: 40),
            make(mode: .explanation, days: 8, score: 90, filler: 1, pace: 9, clarity: 9, structure: 9, vocab: 9, duration: 105, question: "Walk me through how a vaccine works.", feedback: "One of your strongest sessions. The layered explanation held together from start to finish. Vocabulary was precise without being jargon-heavy.", xp: 58),
            make(mode: .impromptu, days: 10, score: 74, filler: 5, pace: 7, clarity: 7, structure: 6, vocab: 7, duration: 71, question: "Describe your ideal workday in under 2 minutes.", feedback: "Good instinct to anchor on values early. The middle section repeated the same point twice — trim it. End on the outcome, not the process.", xp: 33),
            make(mode: .interview, days: 12, score: 65, filler: 8, pace: 6, clarity: 6, structure: 6, vocab: 7, duration: 92, question: "Why do you want to work here?", feedback: "The core answer was solid but the delivery was tentative. Filler words spiked when discussing culture — prep that section more thoroughly. The closing line landed well.", xp: 25),
            make(mode: .explanation, days: 14, score: 86, filler: 2, pace: 8, clarity: 9, structure: 8, vocab: 8, duration: 98, question: "Explain compound interest to a teenager.", feedback: "Strong analogy in the opening — the snowball image worked. Structure was clean: concept, example, implication. Minor rhythm issue in the middle, but overall very polished.", xp: 50),
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

    private var effectiveWeekSessions: [Session] {
        #if DEBUG
        if weekCache.sessions.isEmpty {
            let calendar = Calendar.current
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .distantPast
            return effectiveSessions.filter { $0.date >= weekStart }
        }
        #endif
        return weekCache.sessions
    }

    private var weeklyActivity: [Int] {
        viewModel.weeklyActivity(from: effectiveWeekSessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if effectiveSessions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        weekCalendarCard
                        scoreTrendCard
                        sessionsPerDayCard
                        skillTrendsCard
                        recentSessionsCard
                        modeBreakdownCard
                        milestonesSection
                        allTimeStatsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppColors.bg)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                headerView
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("YOUR JOURNEY")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.dim)
                .kerning(1.2)
            Text("Progress")
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppColors.bg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.sub)
            Text("Complete your first session to see your progress")
                .font(AppFonts.body(16))
                .foregroundStyle(AppColors.sub)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week Calendar

    private var weekCalendarCard: some View {
        let counts = weeklyActivity
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: .now)
        let todayIndex = (today + 5) % 7 // Mon=0 ... Sun=6
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This Week")

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let done = counts[i] > 0
                    let isToday = i == todayIndex
                    let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(done ? (isToday ? AppColors.gold : AppColors.gold.opacity(0.4)) : AppColors.faint)
                                .frame(width: 36, height: 36)

                            if done && isToday {
                                Text("\u{1F525}")
                                    .font(.system(size: 16))
                            } else if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppColors.gold)
                            }
                        }

                        Text(dayLabels[i])
                            .font(AppFonts.body(9))
                            .foregroundStyle(isToday ? AppColors.gold : AppColors.sub)

                        if done {
                            Text("\(counts[i])")
                                .font(AppFonts.body(8))
                                .foregroundStyle(AppColors.dim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        done
                            ? "\(dayNames[i])\(isToday ? ", today" : "") — completed"
                            : "\(dayNames[i])\(isToday ? ", today" : "") — no sessions"
                    )
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Score Trend

    private var scoreTrendCard: some View {
        let scores = viewModel.scoreHistory(from: effectiveSessions)
        let delta: Int = {
            guard scores.count >= 2 else { return 0 }
            return scores.last! - scores.first!
        }()

        return VStack(spacing: 12) {
            HStack {
                SectionHeader(title: "Score Trend")
                Spacer()
                if delta != 0 {
                    Text("\(delta >= 0 ? "\u{2191}" : "\u{2193}") \(delta >= 0 ? "+" : "")\(delta) pts")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(delta >= 0 ? AppColors.teal : AppColors.red)
                }
            }

            if scores.count >= 2 {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let minScore = CGFloat(max(0, (scores.min() ?? 0) - 5))
                    let maxScore = CGFloat(min(100, (scores.max() ?? 100) + 5))
                    let range = max(1, maxScore - minScore)
                    let stepX = width / CGFloat(scores.count - 1)

                    ZStack {
                        // Gradient fill
                        Path { path in
                            for (i, score) in scores.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - ((CGFloat(score) - minScore) / range * height)
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            path.addLine(to: CGPoint(x: CGFloat(scores.count - 1) * stepX, y: height))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gold.opacity(0.3), AppColors.gold.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Line stroke
                        Path { path in
                            for (i, score) in scores.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - ((CGFloat(score) - minScore) / range * height)
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(AppColors.gold, lineWidth: 2.5)
                    }
                }
                .frame(height: 100)

                HStack {
                    Text("\(scores.count) days ago")
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                    Spacer()
                    Text("Today")
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Sessions Per Day

    private var sessionsPerDayCard: some View {
        let counts = weeklyActivity
        let maxCount = max(1, counts.max() ?? 1)
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: .now)
        let todayIndex = (today + 5) % 7

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sessions Per Day")

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let isToday = i == todayIndex
                    VStack(spacing: 4) {
                        if counts[i] > 0 {
                            Text("\(counts[i])")
                                .font(AppFonts.body(9))
                                .foregroundStyle(AppColors.sub)
                        }

                        RoundedRectangle(cornerRadius: 5)
                            .fill(isToday ? AppColors.gold : AppColors.gold.opacity(0.6))
                            .frame(height: max(4, CGFloat(counts[i]) / CGFloat(maxCount) * 80))

                        Text(dayLabels[i])
                            .font(AppFonts.body(9))
                            .foregroundStyle(AppColors.sub)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Skill Trends

    private var skillTrendsCard: some View {
        let previousWeek = effectiveSessions.filter { session in !effectiveWeekSessions.contains(where: { c in c.id == session.id }) }.prefix(20).map { $0 }
        let trends = viewModel.skillTrends(currentWeek: effectiveWeekSessions, previousWeek: previousWeek)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Skill Trends")

            ForEach(trends, id: \.name) { trend in
                // For filler words, lower is better (inverted color logic)
                let isImproved = trend.name == "Filler Words" ? trend.delta <= 0 : trend.delta >= 0

                VStack(spacing: 6) {
                    HStack {
                        Text(trend.name)
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(String(format: "%.1f", trend.previous))
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.dim)
                            Text("\u{2192}")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.dim)
                            Text(String(format: "%.1f", trend.current))
                                .font(AppFonts.bodyBold(13))
                                .foregroundStyle(isImproved ? AppColors.teal : AppColors.red)
                        }
                    }
                    ProgressBar(pct: trend.current * 10, color: isImproved ? AppColors.teal : AppColors.red, height: 4)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Recent Sessions

    @State private var expandedSessionId: UUID?

    private var recentSessionsCard: some View {
        let recent = Array(effectiveSessions.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")

            if recent.isEmpty {
                Text("No sessions yet")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            } else {
                ForEach(recent, id: \.id) { session in
                    let isExpanded = expandedSessionId == session.id

                    VStack(alignment: .leading, spacing: 0) {
                        // Session summary row
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedSessionId = isExpanded ? nil : session.id
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(session.mode.emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 38, height: 38)
                                    .background(session.mode.accentColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.mode.displayName)
                                        .font(AppFonts.bodyMedium(13))
                                        .foregroundStyle(AppColors.text)
                                    HStack(spacing: 6) {
                                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(AppFonts.body(10))
                                            .foregroundStyle(AppColors.sub)
                                        Text("\u{00B7}")
                                            .foregroundStyle(AppColors.dim)
                                        Text("\(Int(session.duration / 60))m \(Int(session.duration) % 60)s")
                                            .font(AppFonts.body(10))
                                            .foregroundStyle(AppColors.sub)
                                    }
                                }

                                Spacer()

                                Text("\(session.overallScore)")
                                    .font(AppFonts.display(20))
                                    .foregroundStyle(AppColors.scoreColor(session.overallScore))

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppColors.dim)
                            }
                        }

                        // Expanded detail
                        if isExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                Divider().background(AppColors.border)

                                // Question
                                Text("Q: \(session.question)")
                                    .font(AppFonts.body(11))
                                    .italic()
                                    .foregroundStyle(AppColors.sub)
                                    .lineLimit(2)

                                // Scores row
                                if session.isAIScored {
                                    let pace = session.metricScores["pace"] ?? 0
                                    let clarity = session.metricScores["clarity"] ?? 0
                                    let structure = session.metricScores["structure"] ?? 0
                                    let vocab = session.metricScores["vocabulary"] ?? 0
                                    HStack(spacing: 0) {
                                        miniMetric(label: "Filler", value: "\(session.fillerCount)", color: session.fillerCount <= 2 ? AppColors.teal : AppColors.red)
                                        miniMetric(label: "Pace", value: "\(pace)/10", color: pace >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Clarity", value: "\(clarity)/10", color: clarity >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Structure", value: "\(structure)/10", color: structure >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Vocab", value: "\(vocab)/10", color: vocab >= 7 ? AppColors.teal : AppColors.gold)
                                    }
                                } else {
                                    HStack(spacing: 0) {
                                        miniMetric(label: "Filler", value: "\(session.fillerCount)", color: session.fillerCount <= 2 ? AppColors.teal : AppColors.red)
                                        miniMetric(label: "Pace", value: "\(session.paceScore)/10", color: session.paceScore >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Clarity", value: "\(session.clarityScore)/10", color: session.clarityScore >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Structure", value: "\(session.structureScore)/10", color: session.structureScore >= 7 ? AppColors.teal : AppColors.gold)
                                        miniMetric(label: "Vocab", value: "\(session.vocabularyScore)/10", color: session.vocabularyScore >= 7 ? AppColors.teal : AppColors.gold)
                                    }
                                }

                                // AI Coach feedback
                                if let feedback = session.aiCoachFeedback {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI COACH")
                                            .font(AppFonts.bodyBold(9))
                                            .foregroundStyle(AppColors.gold)
                                            .kerning(0.8)
                                        Text(feedback)
                                            .font(AppFonts.body(11))
                                            .foregroundStyle(AppColors.sub)
                                            .lineSpacing(4)
                                    }
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(12)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(isExpanded ? AppColors.gold.opacity(0.3) : AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func miniMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFonts.bodyBold(11))
                .foregroundStyle(color)
            Text(label)
                .font(AppFonts.body(8))
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mode Breakdown

    private var modeBreakdownCard: some View {
        let breakdown = viewModel.modeBreakdown(from: Array(effectiveSessions))
        let totalSessions = max(1, breakdown.map(\.count).reduce(0, +))

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mode Breakdown")

            ForEach(breakdown, id: \.mode) { item in
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(item.mode.emoji)
                                .font(.system(size: 14))
                            Text(item.mode.displayName)
                                .font(AppFonts.body(13))
                                .foregroundStyle(AppColors.text)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(item.count) sessions")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.sub)
                            Text("Best \(item.bestScore)")
                                .font(AppFonts.bodyMedium(11))
                                .foregroundStyle(item.mode.accentColor)
                        }
                    }
                    ProgressBar(
                        pct: Double(item.count) / Double(totalSessions) * 100,
                        color: item.mode.accentColor,
                        height: 4
                    )
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        let milestoneAchievements = achievements.filter { !$0.isUnlocked || $0.progress > 0 }.prefix(4)
        let milestoneColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Milestones")

            if !milestoneAchievements.isEmpty {
                LazyVGrid(columns: milestoneColumns, spacing: 10) {
                    ForEach(Array(milestoneAchievements), id: \.id) { achievement in
                        VStack(spacing: 8) {
                            Text(achievement.emoji)
                                .font(.system(size: 22))

                            Text(achievement.name)
                                .font(AppFonts.bodyMedium(12))
                                .foregroundStyle(AppColors.text)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if achievement.isUnlocked {
                                Text("\u{2713} Complete")
                                    .font(AppFonts.bodyMedium(10))
                                    .foregroundStyle(AppColors.teal)
                            } else {
                                ProgressBar(
                                    pct: achievement.progressFraction * 100,
                                    color: AppColors.gold,
                                    height: 4
                                )
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                                .stroke(achievement.isUnlocked ? AppColors.gold : AppColors.border, lineWidth: 1)
                        )
                        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
                    }
                }
            }
        }
        .padding(.horizontal, 0)
    }

    // MARK: - All-Time Stats

    private var allTimeStatsCard: some View {
        let totalSessions = effectiveSessions.count
        let bestScore = effectiveSessions.map(\.overallScore).max() ?? 0
        let totalMinutes = Int(effectiveSessions.map(\.duration).reduce(0, +) / 60)
        let avgScore = effectiveSessions.isEmpty ? 0 : effectiveSessions.map(\.overallScore).reduce(0, +) / effectiveSessions.count

        let statColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "All-Time Stats")

            LazyVGrid(columns: statColumns, spacing: 10) {
                statCell(value: "\(totalSessions)", label: "Sessions")
                statCell(value: "\(bestScore)", label: "Best Score")
                statCell(value: "\(totalMinutes)m", label: "Time Spoken")
                statCell(value: "\(avgScore)", label: "Avg Score")
            }
        }
        .cardStyle()
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
        .padding(.vertical, 10)
    }

}
