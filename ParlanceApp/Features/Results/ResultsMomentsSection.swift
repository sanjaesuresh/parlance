import SwiftUI

/// Best-moment / worst-moment cards. AI-scored sessions get the editorial
/// `AIMomentsCard`; rule-scored sessions get the timestamp-based `MomentsCard`.
struct ResultsMomentsSection: View {
    @Bindable var session: Session

    var body: some View {
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

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
