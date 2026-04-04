import SwiftUI

struct ResultsView: View {
    @ObservedObject var session: Session
    let question: Question
    let onTryAgain: () -> Void
    let onGoHome: () -> Void

    @StateObject private var viewModel = ResultsViewModel()
    @State private var showXPToast = true

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    ScoreRingView(score: session.overallScore)
                        .padding(.top, 24)

                    Text(GamificationService.headlineVerdict(for: session.overallScore))
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(AppColors.text)

                    Text(""\(session.question)"")
                        .font(AppFonts.body(14))
                        .italic()
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    aiCoachCard

                    momentsSection

                    metricsSection

                    upNextSection
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, 16)
            }
            .background(AppColors.bg)

            if showXPToast {
                XPToastView(xpEarned: session.xpEarned, isVisible: $showXPToast)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Coach")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.gold)
                Spacer()

                if session.aiCoachFeedback == nil && !viewModel.isRetryingFeedback {
                    Button {
                        Task { await viewModel.retryFeedback(for: session, question: question) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }

            if let feedback = session.aiCoachFeedback {
                Text(feedback)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            } else if viewModel.isRetryingFeedback {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.border)
                    .frame(height: 60)
                    .shimmering()
            } else {
                Text("Coach feedback unavailable right now. Your scores and metrics are still saved.")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Moments

    private var momentsSection: some View {
        HStack(spacing: 12) {
            if !session.bestMomentText.isEmpty {
                momentCard(
                    title: "Best Moment",
                    timestamp: formatTimestamp(session.bestMomentTimestamp),
                    text: session.bestMomentText,
                    color: AppColors.teal
                )
            }

            if !session.worstMomentText.isEmpty {
                momentCard(
                    title: "Worst Moment",
                    timestamp: formatTimestamp(session.worstMomentTimestamp),
                    text: session.worstMomentText,
                    color: AppColors.red
                )
            }
        }
    }

    private func momentCard(title: String, timestamp: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(color)
                Spacer()
                Text(timestamp)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }
            Text(text)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.text)
                .lineLimit(3)
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        let fillerScore = session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1

        return VStack(spacing: 10) {
            MetricCardView(name: "Filler Words", score: fillerScore, tip: viewModel.fillerTip(for: session))
            MetricCardView(name: "Pace", score: session.paceScore, tip: viewModel.paceTip(for: session))
            MetricCardView(name: "Clarity", score: session.clarityScore, tip: viewModel.clarityTip(for: session))
            MetricCardView(name: "Structure", score: session.structureScore, tip: viewModel.structureTip(for: session))
            MetricCardView(name: "Vocabulary", score: session.vocabularyScore, tip: viewModel.vocabularyTip(for: session))
        }
    }

    // MARK: - Up Next

    private var upNextSection: some View {
        VStack(spacing: 12) {
            Button(action: onTryAgain) {
                Text("Try Again")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onGoHome) {
                Text("Home")
                    .font(AppFonts.bodyMedium(16))
                    .foregroundStyle(AppColors.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
    }

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
