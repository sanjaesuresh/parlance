import XCTest
import SwiftUI
@testable import Parlance

@MainActor
final class ResultsBreakdownSnapshotTests: XCTestCase {

    func test_renderBreakdownScreen_savesPNG() throws {
        let snapshotView = ResultsBreakdownSnapshotComposition()
            .frame(width: 390)
            .background(AppColors.bg)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            XCTFail("Could not produce PNG")
            return
        }

        let outDir = URL(
            fileURLWithPath: "/Users/sanjaesuresh/Apps/Parlance/_docs/mockups/snapshots",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outURL = outDir.appendingPathComponent("results_breakdown_implementation.png")
        try data.write(to: outURL)
        print("Snapshot saved: \(outURL.path)  bytes=\(data.count)")
    }
}

// MARK: - Composition mirroring ResultsView's breakdown stack

private struct ResultsBreakdownSnapshotComposition: View {
    var body: some View {
        VStack(spacing: 0) {
            section(showsTopRule: false) { verdictHero }
            section { breakdown }
            section { moments }
            section { coach }
            section { tone }
            section { upNext }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func section<Content: View>(
        showsTopRule: Bool = true,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            if showsTopRule {
                Rectangle().fill(AppColors.border).frame(height: 1)
            }
            content()
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verdictHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Your average: 62")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
                Text("+6 from avg")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.teal.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 10)

            (
                Text("Room to grow. Focus on ")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
                + Text("delivery confidence")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.red)
                + Text(" first.")
                    .font(AppFonts.display(26))
                    .foregroundStyle(AppColors.text)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)

            Text("\u{201C}Walk me through your pitch for a Series A in two minutes.\u{201D}")
                .font(AppFonts.body(13))
                .italic()
                .foregroundStyle(AppColors.sub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            Text("Level 6 · Polished Speaker · 1:42 · Score 68")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BREAKDOWN")
                .font(AppFonts.bodyBold(10))
                .kerning(1.6)
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 12)
            ForEach(Array(breakdownData.enumerated()), id: \.offset) { _, entry in
                BreakdownMetricRow(
                    name: entry.0,
                    score: entry.1,
                    tip: entry.2,
                    status: BreakdownMetricRow.status(forScore: entry.1)
                )
            }
        }
    }

    private var breakdownData: [(String, Int, String)] {
        [
            ("Filler Words", 4, "11 fillers in 90 seconds, most clustered at sentence starts. Pause for half a beat instead."),
            ("Delivery Confidence", 5, "Three hedges in the first 20 seconds: \"I think,\" \"kind of,\" \"maybe.\" Cut them. The rest of your answer is confident enough to stand without them."),
            ("Persuasiveness", 6, ""),
            ("Structure", 6, "Your opening landed, but the close trailed off. End on the single sentence you most want them to remember."),
            ("Comprehensibility", 7, ""),
            ("Relevance", 8, ""),
            ("Vocabulary", 8, ""),
            ("Pace", 9, ""),
            ("Clarity", 9, "")
        ]
    }

    private var moments: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MOMENTS")
                .font(AppFonts.bodyBold(10))
                .kerning(1.6)
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 4)
            AIMomentsCard(
                bestQuote: "We already have three pilots paying us $50K each.",
                bestReason: "That's the moment they leaned in. Anchor your pitch there.",
                worstQuote: "I think there's a really big market for this.",
                worstReason: "Too tentative for an investor pitch. Lead with conviction."
            )
        }
    }

    private var coach: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppColors.gold.opacity(0.18))
                    Circle().stroke(AppColors.gold.opacity(0.55), lineWidth: 1)
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
                    Text("Pitch · Level 6 · just now")
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            Text("Strong commercial signal in the middle of the pitch, but the opening took 25 seconds to get to what you actually sell. Investors decide in the first 15. Open with the problem and the proof. Cut the throat-clearing.")
                .font(AppFonts.display(16))
                .foregroundStyle(AppColors.text)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(AppColors.gold.opacity(0.18))
                .frame(height: 1)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Text("Practice feedback only. Not professional coaching or medical advice.")
                .font(AppFonts.body(10))
                .italic()
                .foregroundStyle(AppColors.dim)
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

    private var tone: some View {
        ToneAnalysisCard(
            isPro: true,
            emotionResult: EmotionResult(
                dominantEmotion: "Enthusiasm",
                dominantScore: 0.72,
                confidenceScore: 0.64,
                nervousnessScore: 0.38,
                enthusiasmScore: 0.72,
                emotionArc: [0.42, 0.48, 0.55, 0.62, 0.70, 0.85, 0.78, 0.72, 0.68, 0.72]
            ),
            analysisFailed: false,
            onUpgrade: {},
            onTapDetails: {}
        )
    }

    private var upNext: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.gold.opacity(0.2))
                Text("📊").font(.system(size: 20))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Another Pitch · Polished Speaker")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                Text("New question · +50 XP")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
            Spacer()
            Text("›")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.dim)
        }
        .padding(15)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
