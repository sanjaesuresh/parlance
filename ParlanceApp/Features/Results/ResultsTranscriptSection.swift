import SwiftUI

/// Expandable transcript card with inline filler-word highlighting.
///
/// Owns only its expand/collapse state. The highlighted `AttributedString`
/// is precomputed by the parent on first appear (so the breakdown phase
/// transition shows the highlighted version without a one-frame flash).
struct ResultsTranscriptSection: View {
    @Bindable var session: Session
    let highlightedTranscript: AttributedString?

    @State private var transcriptExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your response")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.dim)
                    .kerning(0.4)

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

            if let transcript = highlightedTranscript {
                Text(transcript)
                    .font(AppFonts.body(13))
                    .lineSpacing(5)
                    .lineLimit(transcriptExpanded ? nil : 2)
            } else {
                Text(TranscriptCensor.censor(session.transcript))
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
}
