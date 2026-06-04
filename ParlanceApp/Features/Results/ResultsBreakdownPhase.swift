import SwiftUI

/// Scrollable breakdown phase shown after the user taps "See Breakdown".
/// Distilled to a guided read: relevance warning → verdict hero → coach
/// paragraph → best/worst moments (actionable climax) → per-metric rows →
/// tone (collapsed) → transcript (collapsed). The Up Next CTA lives in a
/// sticky safe-area footer so retry is always reachable.
///
/// Section-level state (transcript expand, tone expand) lives in the child
/// sections. Cross-cutting sheet bindings (paywall, tone-detail) come in
/// from the parent.
struct ResultsBreakdownPhase: View {
    @Bindable var session: Session
    @ObservedObject var viewModel: ResultsViewModel
    let isPro: Bool
    let toneAnalysisFailed: Bool
    let cachedPriorAverage: Int?
    let highlightedTranscript: AttributedString?
    let onTryAgain: () -> Void
    let onGoHome: () -> Void
    @Binding var showPaywall: Bool
    @Binding var showToneDetail: Bool

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let relevance = session.relevanceToPrompt, (25..<60).contains(relevance) {
                    resultsSection(showsTopRule: false) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .foregroundStyle(AppColors.gold)
                                .font(.system(size: 14))
                            Text("This response only partially addressed the prompt. Your coach feedback may be limited.")
                                .font(AppFonts.body(12))
                                .foregroundStyle(AppColors.sub)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    resultsSection { verdictHero }
                } else {
                    resultsSection(showsTopRule: false) { verdictHero }
                }
                resultsSection {
                    ResultsCoachFeedbackSection(session: session, viewModel: viewModel)
                }
                resultsSection {
                    ResultsMomentsSection(session: session)
                }
                resultsSection { breakdownSection }
                resultsSection {
                    ResultsTonePhase(
                        session: session,
                        isPro: isPro,
                        toneAnalysisFailed: toneAnalysisFailed,
                        showPaywall: $showPaywall,
                        showToneDetail: $showToneDetail
                    )
                }
                if session.hasTranscript {
                    resultsSection {
                        ResultsTranscriptSection(
                            session: session,
                            highlightedTranscript: highlightedTranscript
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(AppColors.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            upNextFooter
        }
    }

    // MARK: - Section wrapper

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

    // MARK: - Verdict Hero (breakdown view — small ring + rich headline)

    private var verdictHero: some View {
        VStack(alignment: .center, spacing: 0) {
            ScoreRingView(score: session.overallScore, size: 128)
                .padding(.bottom, 14)

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
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            Text("Level \(session.difficultyLevel) · \(DifficultyLevel.tier(for: session.difficultyLevel)) · \(durationString)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
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

    // MARK: - Breakdown rows

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
            Text("Breakdown")
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
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

    // MARK: - Sticky Up Next footer

    private var upNextFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("Up next")
                    .font(AppFonts.bodyBold(10))
                    .kerning(0.4)
                    .foregroundStyle(AppColors.dim)

                HStack(spacing: 10) {
                    SecondaryButton(title: "Back home", action: onGoHome)
                    PrimaryButton(title: "Try another", action: onTryAgain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(AppColors.card2)
        }
    }
}
