import SwiftUI

/// Wraps `ToneAnalysisCard` for the breakdown screen. The card itself is
/// general-purpose; this view binds it to the results-screen state (Pro
/// gating, sheet trigger, analysis-failed flag).
///
/// Renders inside a collapsible disclosure so the breakdown phase stays
/// distilled. Default collapsed; tap the header to expand.
struct ResultsTonePhase: View {
    @Bindable var session: Session
    let isPro: Bool
    let toneAnalysisFailed: Bool
    @Binding var showPaywall: Bool
    @Binding var showToneDetail: Bool

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack {
                    Text("Tone analysis")
                        .font(AppFonts.bodyBold(10))
                        .foregroundStyle(AppColors.dim)
                        .kerning(0.4)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.sub)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ToneAnalysisCard(
                    isPro: isPro,
                    emotionResult: session.emotionResult,
                    analysisFailed: toneAnalysisFailed,
                    onUpgrade: { showPaywall = true },
                    onTapDetails: { showToneDetail = true }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
