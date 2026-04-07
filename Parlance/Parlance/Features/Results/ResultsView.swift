import SwiftUI

struct ResultsView: View {
    @Bindable var session: Session
    let question: Question
    let onTryAgain: () -> Void
    let onGoHome: () -> Void

    @StateObject private var viewModel = ResultsViewModel()
    @State private var showXPToast = true

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

                    // 8 — Up Next card
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
                text: "\(session.mode.emoji) \(session.mode.displayName)",
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
        }
        .padding(.top, 52)
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: 8) {
            ScoreRingView(score: session.overallScore)

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
                        Task { await viewModel.retryFeedback(for: session, question: question) }
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
                    .foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73)) // #BBB
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
        .background(Color(red: 0.075, green: 0.071, blue: 0.055)) // #13120E
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Transcript

    @State private var transcriptExpanded = false

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR RESPONSE")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.dim)
                    .kerning(0.8)

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

            Text(session.transcript)
                .font(AppFonts.body(13))
                .foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73))
                .lineSpacing(5)
                .lineLimit(transcriptExpanded ? nil : 4)
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
        HStack(spacing: 10) {
            if !session.bestMomentText.isEmpty {
                momentCard(
                    label: "✅ BEST MOMENT",
                    timestamp: formatTimestamp(session.bestMomentTimestamp),
                    text: session.bestMomentText,
                    labelColor: AppColors.teal,
                    bgColor: Color(red: 0.055, green: 0.102, blue: 0.078), // #0E1A14
                    borderColor: AppColors.teal.opacity(0.3)
                )
            }

            if !session.worstMomentText.isEmpty {
                momentCard(
                    label: "⚠️ WEAKEST MOMENT",
                    timestamp: formatTimestamp(session.worstMomentTimestamp),
                    text: session.worstMomentText,
                    labelColor: AppColors.red,
                    bgColor: Color(red: 0.102, green: 0.055, blue: 0.055), // #1A0E0E
                    borderColor: AppColors.red.opacity(0.3)
                )
            }
        }
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
                .foregroundStyle(Color(red: 0.667, green: 0.667, blue: 0.667)) // #AAA
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

            let fillerScore = session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1

            MetricCardView(name: "Filler Words", score: fillerScore, tip: viewModel.fillerTip(for: session))
            MetricCardView(name: "Pace", score: session.paceScore, tip: viewModel.paceTip(for: session))
            MetricCardView(name: "Clarity", score: session.clarityScore, tip: viewModel.clarityTip(for: session))
            MetricCardView(name: "Structure", score: session.structureScore, tip: viewModel.structureTip(for: session))
            MetricCardView(name: "Vocabulary", score: session.vocabularyScore, tip: viewModel.vocabularyTip(for: session))
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
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            )
            .clipped()
    }
}
