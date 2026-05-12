import SwiftUI
import SwiftData

struct ResultsView: View {
    @Bindable var session: Session
    let question: Question
    var toneAnalysisFailed: Bool = false
    let onTryAgain: () -> Void
    let onGoHome: () -> Void

    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = ResultsViewModel()
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var showXPToast = true
    @State private var showPaywall = false
    @State private var showXPBanner = false

    private enum ResultsPhase {
        case scoreReveal, breakdown
    }

    @State private var resultsPhase: ResultsPhase = .scoreReveal
    @State private var displayedXP: Int = 0
    @State private var cachedPriorAverage: Int? = nil
    @State private var xpAnimationTask: Task<Void, Never>? = nil
    @State private var revealHaptic = false
    @State private var breakdownHaptic = false
    @State private var cachedVerdictText: String = ""

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func computeVerdictText() -> String {
        let score = session.overallScore
        if score >= 80 {
            if let best = bestMetricName() {
                return "Strong performance. Your \(best) stood out."
            }
            return "Strong performance."
        } else if score >= 65 {
            if let worst = worstMetricName() {
                return "Getting there. Work on \(worst) next."
            }
            return "Getting there."
        } else {
            if let worst = worstMetricName() {
                return "Room to grow. Focus on \(worst) first."
            }
            return "Room to grow."
        }
    }

    private func bestMetricName() -> String? {
        if session.isAIScored {
            return session.metricScores
                .filter { $0.value > 0 }
                .max(by: { $0.value < $1.value })
                .flatMap { MetricKey(rawValue: $0.key)?.displayName.lowercased() }
        }
        let scores: [(String, Int)] = [
            ("structure", session.structureScore),
            ("vocabulary", session.vocabularyScore),
            ("clarity", session.clarityScore),
            ("pace", session.paceScore),
            ("filler control", session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1)
        ].filter { $0.1 > 0 }
        return scores.max(by: { $0.1 < $1.1 })?.0
    }

    private func worstMetricName() -> String? {
        if session.isAIScored {
            return session.metricScores
                .min(by: { $0.value < $1.value })
                .flatMap { MetricKey(rawValue: $0.key)?.displayName.lowercased() }
        }
        let scores: [(String, Int)] = [
            ("structure", session.structureScore),
            ("vocabulary", session.vocabularyScore),
            ("clarity", session.clarityScore),
            ("pace", session.paceScore),
            ("filler control", session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1)
        ].filter { $0.1 >= 0 }
        return scores.min(by: { $0.1 < $1.1 })?.0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topNavBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                switch resultsPhase {
                case .scoreReveal:
                    scoreRevealScreen
                        .transition(.opacity)
                case .breakdown:
                    ScrollView {
                        VStack(spacing: 0) {
                            resultsSection(showsTopRule: false) { verdictHero }
                            resultsSection { breakdownSection }
                            resultsSection { momentsSection }
                            resultsSection { aiCoachCard }
                            resultsSection {
                                ToneAnalysisCard(
                                    isPro: subscription.isPro,
                                    emotionResult: session.emotionResult,
                                    analysisFailed: toneAnalysisFailed,
                                    onUpgrade: { showPaywall = true },
                                    onTapDetails: { /* hooked up by the tone-detail-sheet stream */ }
                                )
                            }
                            if session.hasTranscript {
                                resultsSection { transcriptCard }
                            }
                            resultsSection { upNextCard }
                                .padding(.bottom, 60)
                        }
                        .padding(.horizontal, 18)
                    }
                    .background(AppColors.bg)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .background(AppColors.bg)

            if showXPToast && resultsPhase == .breakdown {
                XPToastView(xpEarned: session.xpEarned, isVisible: $showXPToast)
                    .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .top) {
            if showXPBanner {
                XPBannerView(xpEarned: session.xpEarned)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: "results")
        }
        .sensoryFeedback(.success, trigger: revealHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: breakdownHaptic)
        .onAppear {
            // Climactic moment — score is now visible. Fire once when the
            // results screen first appears, regardless of phase, so it lands
            // alongside the ring animation rather than after the user taps.
            revealHaptic.toggle()
            cachedVerdictText = computeVerdictText()
            let prior = allSessions.filter { $0.id != session.id }
            if !prior.isEmpty {
                let sum = prior.map(\.overallScore).reduce(0, +)
                cachedPriorAverage = Int((Double(sum) / Double(prior.count)).rounded())
            }
            if session.hasTranscript {
                var attr = AttributedString(session.transcript)
                attr.foregroundColor = AppColors.dim
                let ranges = SpeechAnalyzer.fillerRanges(in: session.transcript)
                for range in ranges {
                    if let attrRange = Range(range, in: attr) {
                        attr[attrRange].foregroundColor = AppColors.red
                        attr[attrRange].backgroundColor = AppColors.red.opacity(0.18)
                        attr[attrRange].font = AppFonts.bodyMedium(13)
                    }
                }
                cachedHighlightedTranscript = attr
            }
        }
    }

    // MARK: - Score Reveal Screen

    private var scoreRevealScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ScoreRingView(score: session.overallScore)
                .padding(.bottom, 20)

            Text(cachedVerdictText)
                .font(AppFonts.display(26))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let avg = cachedPriorAverage {
                let delta = session.overallScore - avg
                HStack(spacing: 8) {
                    Text("Your average: \(avg)")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                    if delta != 0 {
                        Text("\(delta >= 0 ? "+" : "")\(delta)")
                            .font(AppFonts.bodyBold(11))
                            .foregroundStyle(delta >= 0 ? AppColors.teal : AppColors.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((delta >= 0 ? AppColors.teal : AppColors.red).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.gold)
                Text("+\(displayedXP) XP")
                    .font(AppFonts.bodyBold(17))
                    .foregroundStyle(AppColors.gold)
            }
            .padding(.top, 20)
            .onAppear {
                SoundService.play(.xpEarned)
                xpAnimationTask = Task { await animateXP() }
            }
            .onDisappear {
                xpAnimationTask?.cancel()
                xpAnimationTask = nil
            }

            Spacer()

            Text("Score generated by AI · for practice only")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 4)

            Button {
                breakdownHaptic.toggle()
                withAnimation(.easeOut(duration: 0.35)) {
                    resultsPhase = .breakdown
                }
            } label: {
                Text("See Breakdown")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showXPBanner = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showXPBanner = false
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - XP Animation

    private func animateXP() async {
        let target = session.xpEarned
        guard target > 0 else {
            displayedXP = 0
            return
        }
        let steps = 24
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: 55_000_000)
            await MainActor.run {
                displayedXP = (target * i) / steps
            }
        }
        displayedXP = target
    }

    // MARK: - Top Nav Bar

    private var topNavBar: some View {
        HStack {
            // Home button
            Button(action: onGoHome) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Home")
                        .font(AppFonts.bodyMedium(13))
                }
                .foregroundStyle(AppColors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(minHeight: AppConstants.IconButton.hitTarget)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to home")

            Spacer()

            // Mode pill
            PillBadge(
                text: session.mode.displayName,
                emoji: session.mode.emoji,
                color: session.mode.accentColor,
                small: true
            )

            Spacer()

            // Retry button
            Button(action: onTryAgain) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                    Text("Retry")
                        .font(AppFonts.body(12))
                }
                .foregroundStyle(AppColors.sub)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .accessibilityLabel("Retry session")
        }
    }

    // MARK: - Score Hero (breakdown view — no ring, just stats)

    @ViewBuilder
    private func resultsSection<Content: View>(
        showsTopRule: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            if showsTopRule {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            }
            content()
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verdictHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let avg = cachedPriorAverage {
                let delta = session.overallScore - avg
                HStack(spacing: 8) {
                    Text("Your average: \(avg)")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.sub)

                    if delta != 0 {
                        Text("\(delta >= 0 ? "+" : "")\(delta) from avg")
                            .font(AppFonts.bodyBold(10))
                            .foregroundStyle(delta >= 0 ? AppColors.teal : AppColors.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((delta >= 0 ? AppColors.teal : AppColors.red).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 10)
            }

            verdictHeadline
                .padding(.bottom, 10)

            Text("\u{201C}\(session.question)\u{201D}")
                .font(AppFonts.body(13))
                .italic()
                .foregroundStyle(AppColors.sub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            Text("Level \(session.difficultyLevel) · \(DifficultyLevel.tier(for: session.difficultyLevel)) · \(durationString) · Score \(session.overallScore)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verdictHeadline: some View {
        let score = session.overallScore
        let worst = worstMetricName()

        let headline: Text
        if score >= 80 {
            let best = bestMetricName()
            if let best {
                headline = Text("Strong performance. Your ")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
                    + Text(best)
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.teal)
                    + Text(" stood out.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            } else {
                headline = Text("Strong performance.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            }
        } else if score >= 65 {
            if let worst {
                headline = Text("Getting there. Work on ")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
                    + Text(worst)
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.gold)
                    + Text(" next.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            } else {
                headline = Text("Getting there.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            }
        } else {
            if let worst {
                headline = Text("Room to grow. Focus on ")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
                    + Text(worst)
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.red)
                    + Text(" first.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            } else {
                headline = Text("Room to grow.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            }
        }

        return headline
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Question Recap Card

    private var questionRecapCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOU SPOKE ON")
                .font(AppFonts.bodyBold(9))
                .foregroundStyle(AppColors.dim)
                .kerning(1)

            Text(session.question)
                .font(AppFonts.body(12))
                .italic()
                .foregroundStyle(AppColors.sub)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.gold.opacity(0.18))
                    Circle()
                        .stroke(AppColors.gold.opacity(0.55), lineWidth: 1)
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("FROM YOUR COACH")
                        .font(AppFonts.bodyBold(10))
                        .kerning(1.8)
                        .foregroundStyle(AppColors.gold)
                    Text("\(session.mode.displayName) · Level \(session.difficultyLevel) · just now")
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                if session.aiCoachFeedback == nil && !viewModel.isRetryingFeedback {
                    Button {
                        Task { await viewModel.retryFeedback(for: session, question: session.question) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }
            .padding(.bottom, 14)

            if let feedback = session.aiCoachFeedback {
                Text(feedback)
                    .font(AppFonts.display(16))
                    .foregroundStyle(AppColors.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(AppColors.gold.opacity(0.18))
                    .frame(height: 1)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Text("Practice feedback only. Not professional coaching or medical advice.")
                    .font(AppFonts.body(10))
                    .italic()
                    .foregroundStyle(AppColors.dim)
            } else if viewModel.isRetryingFeedback {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.border)
                    .frame(height: 60)
                    .shimmering()
            } else {
                Text("Coach feedback unavailable right now. Your scores and metrics are still saved.")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
                    .lineSpacing(6)
            }
        }
        .padding(EdgeInsets(top: 22, leading: 20, bottom: 18, trailing: 20))
        .background(
            ZStack {
                AppColors.aiCoachBg
                RadialGradient(
                    colors: [AppColors.gold.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.gold.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: AppColors.gold.opacity(0.22), radius: 24, x: 0, y: 12)
    }

    // MARK: - Transcript

    @State private var transcriptExpanded = false
    @State private var cachedHighlightedTranscript: AttributedString? = nil

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR RESPONSE")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.dim)
                    .kerning(0.8)

                if session.fillerCount > 0 {
                    Text("\(session.fillerCount) filler\(session.fillerCount == 1 ? "" : "s")")
                        .font(AppFonts.bodyBold(9))
                        .foregroundStyle(AppColors.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(AppColors.red.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        transcriptExpanded.toggle()
                    }
                } label: {
                    Text(transcriptExpanded ? "Collapse" : "Expand")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.sub)
                }
            }

            if let transcript = cachedHighlightedTranscript {
                Text(transcript)
                    .font(AppFonts.body(13))
                    .lineSpacing(5)
                    .lineLimit(transcriptExpanded ? nil : 2)
            } else {
                Text(session.transcript)
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.dim)
                    .lineSpacing(5)
                    .lineLimit(transcriptExpanded ? nil : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Moments

    private var momentsSection: some View {
        Group {
            if session.isAIScored {
                if !session.bestMomentQuote.isEmpty || !session.worstMomentQuote.isEmpty {
                    AIMomentsCard(
                        bestQuote: session.bestMomentQuote,
                        bestReason: session.bestMomentReason,
                        worstQuote: session.worstMomentQuote,
                        worstReason: session.worstMomentReason
                    )
                } else {
                    Text("No specific moments identified for this session.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } else {
                if !session.bestMomentText.isEmpty || !session.worstMomentText.isEmpty {
                    MomentsCard(
                        bestTimestamp: formatTimestamp(session.bestMomentTimestamp),
                        bestText: session.bestMomentText,
                        worstTimestamp: formatTimestamp(session.worstMomentTimestamp),
                        worstText: session.worstMomentText
                    )
                }
            }
        }
    }

    // MARK: - Breakdown

    private struct BreakdownEntry {
        let name: String
        let score: Int
        let tip: String
    }

    private var breakdownEntries: [BreakdownEntry] {
        if session.isAIScored {
            return MetricKey.metrics(for: session.mode).compactMap { key in
                let score = session.metricScores[key.rawValue] ?? -1
                guard score >= 0 else { return nil }
                let tip = session.metricTips[key.rawValue] ?? ""
                return BreakdownEntry(name: key.displayName, score: score, tip: tip)
            }
        }
        let fillerScore = session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1
        let rows: [BreakdownEntry] = [
            BreakdownEntry(name: "Filler Words", score: fillerScore, tip: ""),
            BreakdownEntry(name: "Pace", score: session.paceScore, tip: ""),
            BreakdownEntry(name: "Clarity", score: session.clarityScore, tip: ""),
            BreakdownEntry(name: "Structure", score: session.structureScore, tip: ""),
            BreakdownEntry(name: "Vocabulary", score: session.vocabularyScore, tip: "")
        ]
        return rows.filter { $0.score >= 0 }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BREAKDOWN")
                .font(AppFonts.bodyBold(10))
                .kerning(1.6)
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 12)

            let sorted = breakdownEntries.sorted { $0.score < $1.score }
            ForEach(Array(sorted.enumerated()), id: \.offset) { _, entry in
                BreakdownMetricRow(
                    name: entry.name,
                    score: entry.score,
                    tip: entry.tip,
                    status: BreakdownMetricRow.status(forScore: entry.score)
                )
            }
        }
    }

    // MARK: - Up Next Card

    private var upNextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Up Next")

            Button(action: onTryAgain) {
                HStack(spacing: 14) {
                    // Mode icon container
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(session.mode.accentColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Text(session.mode.emoji)
                            .font(.system(size: 20))
                    }

                    // Text column
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Another \(session.mode.displayName) — \(DifficultyLevel.tier(for: session.difficultyLevel))")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)

                        Text("New question · +\(AppConstants.baseXP) XP")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                    }

                    Spacer()

                    // Chevron
                    Text("›")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AppColors.dim)
                }
                .padding(15)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

