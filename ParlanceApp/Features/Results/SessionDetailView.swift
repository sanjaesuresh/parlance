import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Bindable var session: Session

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var showPaywall = false
    @State private var transcriptExpanded = false
    @State private var cachedHighlightedTranscript: AttributedString? = nil

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var dateLine: String {
        let date = session.date.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(session.mode.displayName) · Level \(session.difficultyLevel) · \(date)"
    }

    var body: some View {
        VStack(spacing: 0) {
            topNavBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 0) {
                    section(showsTopRule: false) { verdictHero }
                    section { breakdownSection }
                    section { momentsSection }
                    section { aiCoachCard }
                    section {
                        ToneAnalysisCard(
                            isPro: subscription.isPro,
                            emotionResult: session.emotionResult,
                            analysisFailed: false,
                            onUpgrade: { showPaywall = true },
                            onTapDetails: {}
                        )
                    }
                    if session.hasTranscript {
                        section { transcriptCard }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.bg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: "session-detail")
        }
        .onAppear {
            guard session.hasTranscript, cachedHighlightedTranscript == nil else { return }
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

    // MARK: - Top Nav

    private var topNavBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Back")
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
            .accessibilityLabel("Back")

            Spacer()

            PillBadge(
                text: session.mode.displayName,
                emoji: session.mode.emoji,
                color: session.mode.accentColor,
                small: true
            )

            Spacer()

            Text("\(session.overallScore)")
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.scoreColor(session.overallScore))
                .frame(minWidth: 44, alignment: .trailing)
                .accessibilityLabel("Score \(session.overallScore)")
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func section<Content: View>(
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

    // MARK: - Verdict Hero (no "vs avg" — historical)

    private var verdictHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\u{201C}\(session.question)\u{201D}")
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Level \(session.difficultyLevel) · \(DifficultyLevel.tier(for: session.difficultyLevel)) · \(durationString)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - AI Coach (no retry — historical)

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
                    Text(dateLine)
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()
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
            } else {
                Text("Coach feedback wasn't generated for this session.")
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

    // MARK: - Helpers

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
