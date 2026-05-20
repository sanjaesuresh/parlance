import SwiftUI
import SwiftData

/// Top-level results screen. Owns the two-phase state machine (score reveal
/// → breakdown), the XP banner / toast overlays, the paywall and tone-detail
/// sheets, and the top nav bar. Each phase's actual content lives in a
/// sibling view: see `ResultsScorePhase` and `ResultsBreakdownPhase`.
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
    @State private var showToneDetail = false

    private enum ResultsPhase {
        case scoreReveal, breakdown
    }

    @State private var resultsPhase: ResultsPhase = .scoreReveal
    @State private var cachedPriorAverage: Int? = nil
    @State private var revealHaptic = false
    @State private var breakdownHaptic = false
    @State private var cachedVerdictText: String = ""
    @State private var cachedHighlightedTranscript: AttributedString? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topNavBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                switch resultsPhase {
                case .scoreReveal:
                    ResultsScorePhase(
                        session: session,
                        cachedPriorAverage: cachedPriorAverage,
                        cachedVerdictText: cachedVerdictText,
                        showXPBanner: $showXPBanner,
                        onSeeBreakdown: {
                            breakdownHaptic.toggle()
                            withAnimation(.easeOut(duration: 0.35)) {
                                resultsPhase = .breakdown
                            }
                        }
                    )
                    .transition(.opacity)
                case .breakdown:
                    ResultsBreakdownPhase(
                        session: session,
                        viewModel: viewModel,
                        isPro: subscription.isPro,
                        toneAnalysisFailed: toneAnalysisFailed,
                        cachedPriorAverage: cachedPriorAverage,
                        highlightedTranscript: cachedHighlightedTranscript,
                        onTryAgain: onTryAgain,
                        onGoHome: onGoHome,
                        showPaywall: $showPaywall,
                        showToneDetail: $showToneDetail
                    )
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
        .sheet(isPresented: $showToneDetail) {
            if let result = session.emotionResult {
                ToneDetailSheet(emotionResult: result, sessionDuration: session.duration)
            }
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
                let censored = TranscriptCensor.censor(session.transcript)
                var attr = AttributedString(censored)
                attr.foregroundColor = AppColors.dim
                let ranges = SpeechAnalyzer.fillerRanges(in: censored)
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

    // MARK: - Verdict text (plain-string variant used during score reveal)

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
}
