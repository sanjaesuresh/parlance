import SwiftUI

/// AI coach paragraph card on the breakdown screen — includes the retry
/// affordance when the Haiku call failed and the shimmer placeholder while
/// a retry is in flight.
struct ResultsCoachFeedbackSection: View {
    @Bindable var session: Session
    @ObservedObject var viewModel: ResultsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("From your coach")
                    .font(AppFonts.display(18))
                    .foregroundStyle(AppColors.text)
                Text("\(session.mode.displayName) · Level \(session.difficultyLevel) · just now")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }
            .padding(.bottom, 14)

            if let feedback = session.aiCoachFeedback {
                Text(feedback)
                    .font(AppFonts.display(16))
                    .foregroundStyle(AppColors.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Text("Practice feedback only. Not professional coaching or medical advice.")
                    .font(AppFonts.body(10))
                    .italic()
                    .foregroundStyle(AppColors.sub)
            } else if viewModel.isRetryingFeedback {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.border)
                    .frame(height: 60)
                    .shimmering()
            } else {
                Text("Coach feedback unavailable right now. Your scores and metrics are still saved.")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
                    .lineSpacing(6)
                    .padding(.bottom, 14)

                SecondaryButton(title: "Retry", icon: "arrow.clockwise") {
                    Task { await viewModel.retryFeedback(for: session, question: session.question) }
                }
            }
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
