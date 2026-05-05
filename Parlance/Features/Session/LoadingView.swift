import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let level: Int
    let question: Question
    let onReady: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                if let onCancel {
                    Button(action: onCancel) {
                        Text("← Back")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Cancel")
                } else {
                    Spacer().frame(width: 72)
                }

                Spacer()

                HStack(spacing: 7) {
                    PillBadge(text: mode.displayName, emoji: mode.emoji, color: mode.accentColor, small: true)
                    Text("Lv \(level)")
                        .font(AppFonts.bodyMedium(10))
                        .foregroundStyle(AppColors.sub)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(AppColors.card)
                        .clipShape(Capsule())
                }

                Spacer()

                Spacer().frame(width: 72)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // One-liner instruction
                    Text("Read the prompt, then tap to begin recording.")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Prompt card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 7) {
                            Text(DifficultyLevel.tier(for: level))
                                .font(AppFonts.bodyMedium(10))
                                .foregroundStyle(AppColors.dim)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(AppColors.faint)
                                .clipShape(Capsule())

                            PillBadge(text: "\(question.targetDuration)s", emoji: "⏱", color: mode.accentColor, small: true)
                        }

                        Text("\"\(question.question)\"")
                            .font(AppFonts.display(20))
                            .foregroundStyle(AppColors.text)
                            .lineSpacing(6)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    // Coaching tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COACHING TIPS")
                            .font(AppFonts.bodyBold(10))
                            .foregroundStyle(AppColors.dim)
                            .kerning(1)

                        ForEach(Array(question.tips.enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(AppFonts.bodyBold(12))
                                    .foregroundStyle(mode.accentColor)
                                    .frame(width: 18, alignment: .center)
                                    .padding(.top, 1)
                                Text(tip)
                                    .font(AppFonts.body(12))
                                    .foregroundStyle(AppColors.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 140)
            }

            Spacer(minLength: 0)

            // Tap when ready button
            Button(action: onReady) {
                Text("Tap when ready")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Tap when ready to record")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg.ignoresSafeArea())
    }
}
