import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var achievements: [Achievement]
    @StateObject private var viewModel = ProgressViewModel()
    @State private var cachedWeekSessions: [Session] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
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
            .onAppear {
                cachedWeekSessions = PersistenceService.shared.sessionsThisWeek()
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
        let counts = viewModel.weeklyActivity(from: cachedWeekSessions)
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
                            ? "\(dayNames[i])\(isToday ? ", today" : ""), completed"
                            : "\(dayNames[i])\(isToday ? ", today" : ""), no sessions"
                    )
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Score Trend

    private var scoreTrendCard: some View {
        let scores = viewModel.scoreHistory(from: sessions)
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
        let counts = viewModel.weeklyActivity(from: cachedWeekSessions)
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
        let previousWeek = sessions.filter { session in !cachedWeekSessions.contains(where: { c in c.id == session.id }) }.prefix(20).map { $0 }
        let trends = viewModel.skillTrends(currentWeek: cachedWeekSessions, previousWeek: previousWeek)

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
        let recent = Array(sessions.prefix(5))

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
        let breakdown = viewModel.modeBreakdown(from: Array(sessions))
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
                            Text(achievementEmoji(for: achievement.iconName))
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
        let totalSessions = sessions.count
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let totalMinutes = Int(sessions.map(\.duration).reduce(0, +) / 60)
        let avgScore = sessions.isEmpty ? 0 : sessions.map(\.overallScore).reduce(0, +) / sessions.count

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

    // MARK: - Helpers

    private func achievementEmoji(for iconName: String) -> String {
        switch iconName {
        case "mic.fill": return "\u{1F3A4}"
        case "flame.fill": return "\u{1F525}"
        case "briefcase.fill": return "\u{1F4BC}"
        case "star.fill": return "\u{2B50}"
        case "checkmark.seal.fill": return "\u{2705}"
        case "trophy.fill": return "\u{1F3C6}"
        case "repeat": return "\u{1F504}"
        case "crown.fill": return "\u{1F451}"
        default: return "\u{1F3AF}"
        }
    }
}
