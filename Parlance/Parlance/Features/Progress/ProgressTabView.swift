import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var achievements: [Achievement]
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        scoreHistoryChart
                        weeklyActivityChart
                        skillTrendsSection
                        modeBreakdownSection
                        milestonesSection
                        recentSessionsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppColors.bg)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }

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

    // MARK: - Score History

    private var scoreHistoryChart: some View {
        let scores = viewModel.scoreHistory(from: sessions)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Score History")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 120
                let stepX = scores.count > 1 ? width / CGFloat(scores.count - 1) : width
                Path { path in
                    for (i, score) in scores.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = height - (CGFloat(score) / 100.0 * height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(AppColors.teal, lineWidth: 2)
            }
            .frame(height: 120)
        }
        .cardStyle()
    }

    // MARK: - Weekly Activity

    private var weeklyActivityChart: some View {
        let weekSessions = PersistenceService.shared.sessionsThisWeek()
        let counts = viewModel.weeklyActivity(from: weekSessions)
        let maxCount = max(1, counts.max() ?? 1)
        let days = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(counts[i] > 0 ? AppColors.gold : AppColors.border)
                            .frame(width: 30, height: max(4, CGFloat(counts[i]) / CGFloat(maxCount) * 60))

                        Text(days[i])
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    // MARK: - Skill Trends

    private var skillTrendsSection: some View {
        let currentWeek = PersistenceService.shared.sessionsThisWeek()
        let previousWeek = sessions.filter { session in !currentWeek.contains(where: { c in c.id == session.id }) }.prefix(20).map { $0 }
        let trends = viewModel.skillTrends(currentWeek: currentWeek, previousWeek: previousWeek)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Skill Trends")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(trends, id: \.name) { trend in
                HStack {
                    Text(trend.name)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text(String(format: "%.1f", trend.current))
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.text)
                    Image(systemName: trend.delta >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10))
                        .foregroundStyle(trend.delta >= 0 ? AppColors.teal : AppColors.red)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Mode Breakdown

    private var modeBreakdownSection: some View {
        let breakdown = viewModel.modeBreakdown(from: Array(sessions))

        return VStack(alignment: .leading, spacing: 8) {
            Text("Mode Breakdown")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(breakdown, id: \.mode) { item in
                HStack {
                    Text(item.mode.emoji)
                    Text(item.mode.displayName)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(item.count) sessions")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                    Text("Best: \(item.bestScore)")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.teal)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        let inProgress = achievements.filter { !$0.isUnlocked && $0.progress > 0 }

        return Group {
            if !inProgress.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones")
                        .font(AppFonts.bodyBold(16))
                        .foregroundStyle(AppColors.text)

                    ForEach(inProgress, id: \.id) { achievement in
                        HStack {
                            Image(systemName: achievement.iconName)
                                .foregroundStyle(AppColors.sub)
                            Text(achievement.name)
                                .font(AppFonts.body(14))
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            Text("\(achievement.progress)/\(achievement.goal)")
                                .font(AppFonts.bodyMedium(12))
                                .foregroundStyle(AppColors.gold)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(sessions.prefix(10), id: \.id) { session in
                HStack {
                    Text(session.mode.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.mode.displayName)
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                    Spacer()
                    Text("\(session.overallScore)")
                        .font(AppFonts.display(18))
                        .foregroundStyle(session.overallScore >= 80 ? AppColors.teal : session.overallScore >= 60 ? AppColors.gold : AppColors.red)
                }
                .padding(.vertical, 4)

                if session.id != sessions.prefix(10).last?.id {
                    Divider().background(AppColors.border)
                }
            }
        }
        .cardStyle()
    }
}
