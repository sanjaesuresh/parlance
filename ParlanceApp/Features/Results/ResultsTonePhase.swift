import SwiftUI

/// Wraps `ToneAnalysisCard` for the breakdown screen. The card itself is
/// general-purpose; this view binds it to the results-screen state (Pro
/// gating, sheet trigger, analysis-failed flag).
struct ResultsTonePhase: View {
    @Bindable var session: Session
    let isPro: Bool
    let toneAnalysisFailed: Bool
    @Binding var showPaywall: Bool
    @Binding var showToneDetail: Bool

    var body: some View {
        ToneAnalysisCard(
            isPro: isPro,
            emotionResult: session.emotionResult,
            analysisFailed: toneAnalysisFailed,
            onUpgrade: { showPaywall = true },
            onTapDetails: { showToneDetail = true }
        )
    }
}
