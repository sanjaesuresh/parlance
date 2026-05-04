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

    /// Average of sessions prior to this one (exclusive of current).
    private var priorAverage: Int? {
        let prior = allSessions.filter { $0.id != session.id }
        guard !prior.isEmpty else { return nil }
        return prior.map(\.overallScore).reduce(0, +) / prior.count
    }

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var verdictText: String {
        let score = session.overallScore
        if score >= 80 { return "Strong performance." }
        if score >= 65 { return "Getting there." }
        return "Room to grow."
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // 1 — Top nav bar
                    topNavBar

                    // 2 — Score hero
                    scoreHero

                    // 3 — Question recap card
                    questionRecapCard

                    // 4 — AI Coach card
                    aiCoachCard

                    // 5 — Your Response (transcript)
                    if session.hasTranscript {
                        transcriptCard
                    }

                    // 6 — Best / Worst moments
                    momentsSection

                    // 7 — Breakdown section
                    breakdownSection

                    // 8 — Tone analysis
                    ToneAnalysisCard(
                        isPro: subscription.isPro,
                        emotionResult: session.emotionResult,
                        onUpgrade: { showPaywall = true }
                    )

                    // 9 — Up Next card
                    upNextCard
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, 16)
            }
            .background(AppColors.bg)

            // XP Toast overlay
            if showXPToast {
                XPToastView(xpEarned: session.xpEarned, isVisible: $showXPToast)
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
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
        .padding(.top, 52)
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: 8) {
            ScoreRingView(score: session.overallScore)

            if let avg = priorAverage {
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

    private var highlightedTranscript: AttributedString {
        var attr = AttributedString(session.transcript)
        // Base styling
        attr.foregroundColor = AppColors.dim

        let ranges = SpeechAnalyzer.fillerRanges(in: session.transcript)
        for range in ranges {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].foregroundColor = AppColors.red
                attr[attrRange].backgroundColor = AppColors.red.opacity(0.18)
                attr[attrRange].font = AppFonts.bodyMedium(13)
            }
        }
        return attr
    }

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

            Text(highlightedTranscript)
                .font(AppFonts.body(13))
                .lineSpacing(5)
                .lineLimit(transcriptExpanded ? nil : 2)
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
                            aiMomentCard(
                                label: "✅ BEST MOMENT",
                                quote: session.bestMomentQuote,
                                reason: session.bestMomentReason,
                                labelColor: AppColors.teal,
                                bgColor: AppColors.momentBestBg,
                                borderColor: AppColors.teal.opacity(0.3)
                            )
                        }
                        if !session.worstMomentQuote.isEmpty {
                            aiMomentCard(
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
                        momentCard(
                            label: "✅ BEST MOMENT",
                            timestamp: formatTimestamp(session.bestMomentTimestamp),
                            text: session.bestMomentText,
                            labelColor: AppColors.teal,
                            bgColor: AppColors.momentBestBg,
                            borderColor: AppColors.teal.opacity(0.3)
                        )
                    }
                    if !session.worstMomentText.isEmpty {
                        momentCard(
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

    private func aiMomentCard(
        label: String,
        quote: String,
        reason: String,
        labelColor: Color,
        bgColor: Color,
        borderColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(labelColor)
                .kerning(0.5)

            Text("\u{201C}\(quote)\u{201D}")
                .font(AppFonts.body(11))
                .italic()
                .foregroundStyle(AppColors.dim)
                .lineLimit(3)
                .lineSpacing(2)

            if !reason.isEmpty {
                Text(reason)
                    .font(AppFonts.body(10))
                    .foregroundStyle(AppColors.dim)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func momentCard(
        label: String,
        timestamp: String,
        text: String,
        labelColor: Color,
        bgColor: Color,
        borderColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(labelColor)
                .kerning(0.5)

            Text("\(timestamp) — \(text)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .lineLimit(3)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
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

                        Text("New question · +120 XP")
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

// MARK: - Shimmer Modifier

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.1), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            )
            .clipped()
    }
}
