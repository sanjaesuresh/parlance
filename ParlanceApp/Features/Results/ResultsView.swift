import SwiftUI
import SwiftData

struct ResultsView: View {
    @Bindable var session: Session
    let question: Question
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

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var verdictText: String {
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
                    .padding(.top, 16)

                switch resultsPhase {
                case .scoreReveal:
                    scoreRevealScreen
                        .transition(.opacity)
                case .breakdown:
                    ScrollView {
                        VStack(spacing: 20) {
                            // 1 — Score hero (without ring — that's on scoreRevealScreen)
                            scoreHero

                            // 2 — Question recap card
                            questionRecapCard

                            // 3 — AI Coach card
                            aiCoachCard

                            // 4 — Your Response (transcript)
                            if session.hasTranscript {
                                transcriptCard
                            }

                            // 5 — Best / Worst moments
                            momentsSection

                            // 6 — Breakdown section
                            breakdownSection

                            // 7 — Tone analysis
                            ToneAnalysisCard(
                                isPro: subscription.isPro,
                                emotionResult: session.emotionResult,
                                onUpgrade: { showPaywall = true }
                            )

                            // 8 — Up Next card
                            upNextCard
                                .padding(.bottom, 60)
                        }
                        .padding(.horizontal, 16)
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

            Text(verdictText)
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
                    Text("Home")
                        .font(AppFonts.bodyMedium(13))
                }
                .foregroundStyle(AppColors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

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
        .padding(.top, 12)
    }

    // MARK: - Score Hero (breakdown view — no ring, just stats)

    private var scoreHero: some View {
        VStack(spacing: 8) {
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
            }

            Text(verdictText)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)

            Text("Level \(session.difficultyLevel) · \(DifficultyLevel.tier(for: session.difficultyLevel)) · \(durationString)")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.dim)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🤖 AI COACH FEEDBACK")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.gold)
                    .kerning(0.8)

                Spacer()

                if session.aiCoachFeedback == nil && !viewModel.isRetryingFeedback {
                    Button {
                        Task { await viewModel.retryFeedback(for: session, question: session.question) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }

            if let feedback = session.aiCoachFeedback {
                Text(feedback)
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.dim)
                    .lineSpacing(6)
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
        .padding(18)
        .background(AppColors.aiCoachBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
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
                    HStack(spacing: 10) {
                        if !session.bestMomentQuote.isEmpty {
                            AIMomentCard(
                                label: "✅ BEST MOMENT",
                                quote: session.bestMomentQuote,
                                reason: session.bestMomentReason,
                                labelColor: AppColors.teal,
                                bgColor: AppColors.momentBestBg,
                                borderColor: AppColors.teal.opacity(0.3)
                            )
                        }
                        if !session.worstMomentQuote.isEmpty {
                            AIMomentCard(
                                label: "⚠️ WEAKEST MOMENT",
                                quote: session.worstMomentQuote,
                                reason: session.worstMomentReason,
                                labelColor: AppColors.red,
                                bgColor: AppColors.momentWorstBg,
                                borderColor: AppColors.red.opacity(0.3)
                            )
                        }
                    }
                } else {
                    Text("No specific moments identified for this session.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } else {
                HStack(spacing: 10) {
                    if !session.bestMomentText.isEmpty {
                        MomentCard(
                            label: "✅ BEST MOMENT",
                            timestamp: formatTimestamp(session.bestMomentTimestamp),
                            text: session.bestMomentText,
                            labelColor: AppColors.teal,
                            bgColor: AppColors.momentBestBg,
                            borderColor: AppColors.teal.opacity(0.3)
                        )
                    }
                    if !session.worstMomentText.isEmpty {
                        MomentCard(
                            label: "⚠️ WEAKEST MOMENT",
                            timestamp: formatTimestamp(session.worstMomentTimestamp),
                            text: session.worstMomentText,
                            labelColor: AppColors.red,
                            bgColor: AppColors.momentWorstBg,
                            borderColor: AppColors.red.opacity(0.3)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Breakdown")

            if session.isAIScored {
                let metrics = MetricKey.metrics(for: session.mode)
                ForEach(metrics, id: \.rawValue) { key in
                    let score = session.metricScores[key.rawValue] ?? -1
                    let tip = session.metricTips[key.rawValue] ?? ""
                    MetricCardView(
                        name: key.displayName,
                        description: key.metricDescription,
                        score: score,
                        tip: tip
                    )
                }
            } else {
                let fillerScore = session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1
                MetricCardView(name: "Filler Words", description: "Ums, uhs, and verbal crutches", score: fillerScore, tip: "")
                MetricCardView(name: "Pace", description: "Speaking speed and rhythm", score: session.paceScore, tip: "")
                MetricCardView(name: "Clarity", description: "How easy your words are to follow", score: session.clarityScore, tip: "")
                MetricCardView(name: "Structure", description: "Opening, body, and closing flow", score: session.structureScore, tip: "")
                MetricCardView(name: "Vocabulary", description: "Word choice strength and variety", score: session.vocabularyScore, tip: "")
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

