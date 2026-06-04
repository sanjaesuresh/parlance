import SwiftUI

struct SamplePreviewView: View {
    let onDismiss: () -> Void
    let onSignUp: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    questionCard
                    scoreRing
                    aiCoachCard
                    metricsSection
                    footnote
                    signUpButton
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(AppColors.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(AppFonts.bodyMedium(13))
                        }
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Sample preview")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.sub)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Question Card

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sample question")
                .font(AppFonts.bodyBold(9))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)

            Text("Tell me about a time you led a team through a difficult situation.")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)
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

    // MARK: - Score Ring

    private var scoreRing: some View {
        VStack(spacing: 12) {
            ScoreRingView(score: 78)

            Text("Getting there. Work on structure next.")
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From your coach")
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(AppColors.gold)
                .kerning(0.4)

            Text("Solid STAR structure: your example was specific and the outcome tied to your actions. Trim the preamble next time. The first 12 seconds added nothing concrete. Pace was steady; vocabulary was strong without being jargon-heavy.")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.dim)
                .lineSpacing(6)
        }
        .padding(18)
        .background(AppColors.aiCoachBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Breakdown")
                .font(AppFonts.bodyBold(9))
                .foregroundStyle(AppColors.dim)
                .kerning(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            MetricCardView(name: "Filler Words", description: "Ums, uhs, and verbal crutches", score: 8, tip: "")
            MetricCardView(name: "Pace", description: "Speaking speed and rhythm", score: 9, tip: "")
            MetricCardView(name: "Structure", description: "Opening, body, and closing flow", score: 8, tip: "")
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("Practice feedback only. Not professional coaching or medical advice.")
            .font(AppFonts.body(11))
            .italic()
            .foregroundStyle(AppColors.dim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - CTA

    private var signUpButton: some View {
        Button(action: onSignUp) {
            Text("Sign up to try yours")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.gold)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        }
    }
}
