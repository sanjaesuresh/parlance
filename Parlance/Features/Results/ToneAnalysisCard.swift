import SwiftUI

struct ToneAnalysisCard: View {
    let isPro: Bool
    let emotionResult: EmotionResult?
    let onUpgrade: () -> Void

    var body: some View {
        if isPro, let result = emotionResult {
            paidCard(result: result)
        } else {
            teaserCard
        }
    }

    private func paidCard(result: EmotionResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TONE ANALYSIS")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.purple)
                    .kerning(0.8)
                Spacer()
                proLabel
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Dominant: \(result.dominantEmotion)")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                Text(String(format: "Score: %.0f%%", result.dominantScore * 100))
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }

            VStack(spacing: 8) {
                emotionBar(label: "Confidence", score: result.confidenceScore, color: AppColors.teal)
                emotionBar(label: "Nervousness", score: result.nervousnessScore, color: AppColors.red)
                emotionBar(label: "Enthusiasm", score: result.enthusiasmScore, color: AppColors.gold)
            }

            if result.emotionArc.count >= 2 {
                arcRow(arc: result.emotionArc)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.purple.opacity(0.35), lineWidth: 1)
        )
    }

    private func emotionBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                Spacer()
                Text(String(format: "%.0f%%", score * 100))
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.border)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(score, 0), 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func arcRow(arc: [Double]) -> some View {
        let first = arc.first ?? 0
        let last = arc.last ?? 0
        let delta = last - first
        let direction: String
        let color: Color
        if delta >= 0.05 {
            direction = "Improved"
            color = AppColors.teal
        } else if delta <= -0.05 {
            direction = "Declined"
            color = AppColors.red
        } else {
            direction = "Steady"
            color = AppColors.sub
        }

        return HStack(spacing: 6) {
            Text("Confidence arc:")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
            Text("\(direction) - \(String(format: "%.0f%%", first * 100)) -> \(String(format: "%.0f%%", last * 100))")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(color)
        }
    }

    private var teaserCard: some View {
        ZStack {
            mockCardContent
                .blur(radius: 5)
                .allowsHitTesting(false)

            Color.black.opacity(0.45)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.gold)

                Text("Tone Analysis")
                    .font(AppFonts.display(17))
                    .foregroundStyle(AppColors.text)

                Text("How confident, nervous, and enthusiastic you actually sounded")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button(action: onUpgrade) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                        Text("Upgrade to Pro")
                            .font(AppFonts.bodyBold(13))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppColors.gold)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
    }

    private var mockCardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TONE ANALYSIS")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(AppColors.purple)
                    .kerning(0.8)
                Spacer()
                proLabel
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Dominant: Confidence")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                Text("Score: 72%")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }
            VStack(spacing: 8) {
                emotionBar(label: "Confidence", score: 0.72, color: AppColors.teal)
                emotionBar(label: "Nervousness", score: 0.31, color: AppColors.red)
                emotionBar(label: "Enthusiasm", score: 0.45, color: AppColors.gold)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
    }

    private var proLabel: some View {
        Text("PRO")
            .font(AppFonts.bodyBold(9))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppColors.gold)
            .clipShape(Capsule())
    }
}
