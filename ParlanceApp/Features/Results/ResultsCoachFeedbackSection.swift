import SwiftUI

/// AI coach paragraph card on the breakdown screen — includes the retry
/// affordance when the Haiku call failed and the shimmer placeholder while
/// a retry is in flight.
struct ResultsCoachFeedbackSection: View {
    @Bindable var session: Session
    @ObservedObject var viewModel: ResultsViewModel

    var body: some View {
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
                    Text("\(session.mode.displayName) · Level \(session.difficultyLevel) · just now")
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                if session.aiCoachFeedback == nil && !viewModel.isRetryingFeedback {
                    Button {
                        Task { await viewModel.retryFeedback(for: session, question: session.question) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.sub)
                    }
                }
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
}
