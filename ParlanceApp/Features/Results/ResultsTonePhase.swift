import SwiftUI

/// Wraps `ToneAnalysisCard` for the breakdown screen. The card itself is
/// general-purpose; this view binds it to the results-screen state (Pro
/// gating, sheet trigger, analysis-failed flag).
///
/// Always rendered expanded — free users see the locked teaser, Pro users
/// see the full card. Tone analysis is the headline Pro feature on this
/// screen and should never be hidden behind a disclosure.
struct ResultsTonePhase: View {
    @Bindable var session: Session
    let isPro: Bool
    let toneAnalysisFailed: Bool
    @Binding var showPaywall: Bool
    @Binding var showToneDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone analysis")
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)

            ToneAnalysisCard(
                isPro: isPro,
                emotionResult: session.emotionResult,
                analysisFailed: toneAnalysisFailed,
                onUpgrade: { showPaywall = true },
                onTapDetails: { showToneDetail = true }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
