import SwiftUI

struct ToneAnalysisCard: View {
    let isPro: Bool
    let emotionResult: EmotionResult?
    var analysisFailed: Bool = false
    let onUpgrade: () -> Void
    var onTapDetails: () -> Void = {}

    var body: some View {
        if isPro {
            if let result = emotionResult {
                paidCard(result: result)
            } else {
                unavailableCard
            }
        } else {
            teaserCard
        }
    }

    private var unavailableCard: some View {
        let isFailure = analysisFailed
        let title = isFailure
            ? "Tone analysis couldn't run"
            : "Tone analysis isn't available for this session"
        let body = isFailure
            ? "We couldn't reach the tone analysis service for this session, usually a network hiccup. Your next recording will include it."
            : "Sessions recorded before you upgraded to Pro don't include tone analysis. Your next recording will."
        let accent = isFailure ? AppColors.gold : AppColors.purple
        let icon = isFailure ? "wifi.exclamationmark" : "waveform"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TONE ANALYSIS")
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(accent)
                    .kerning(0.8)
                Spacer()
                proLabel
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.text)
                    Text(body)
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func paidCard(result: EmotionResult) -> some View {
        let percent = Int((result.dominantScore * 100).rounded())
        let arc = result.emotionArc
        let firstVal = arc.first ?? 0
        let lastVal = arc.last ?? 0
        let delta = lastVal - firstVal
        let arrow: String
        let deltaColor: Color
        if delta >= 0.05 {
            arrow = "↑"
            deltaColor = AppColors.teal
        } else if delta <= -0.05 {
            arrow = "↓"
            deltaColor = AppColors.red
        } else {
            arrow = "→"
            deltaColor = AppColors.teal
        }
        let firstPct = Int((firstVal * 100).rounded())
        let lastPct = Int((lastVal * 100).rounded())

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("VOCAL TONE")
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.8)
                    .foregroundStyle(AppColors.purple)
                Spacer()
                HStack(spacing: 5) {
                    Text("✦")
                        .font(.system(size: 11))
                    Text("PRO")
                        .font(AppFonts.bodyBold(9.5))
                        .kerning(1)
                }
                .foregroundStyle(AppColors.onGold)
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.71, blue: 0.28), AppColors.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .shadow(color: AppColors.gold.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR STRONGEST SIGNAL")
                    .font(AppFonts.bodyBold(9.5))
                    .kerning(1.8)
                    .foregroundStyle(AppColors.dim)
                Spacer().frame(height: 4)
                Text(result.dominantEmotion)
                    .font(AppFonts.display(28))
                    .foregroundStyle(AppColors.text)
                Spacer().frame(height: 6)
                (
                    Text("\(percent)% ")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.text)
                    + Text("· came through across most of your delivery")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                )
            }
            .padding(.bottom, 16)

            ToneSparklineView(arc: result.emotionArc)
                .padding(.bottom, 16)

            VStack(spacing: 10) {
                emotionBar(label: "Enthusiasm", score: result.enthusiasmScore, color: AppColors.teal)
                // Temporary mapping: "Determination" uses confidenceScore until EmotionResult exposes a dedicated field.
                emotionBar(label: "Determination", score: result.confidenceScore, color: AppColors.gold)
                emotionBar(label: "Nervousness", score: result.nervousnessScore, color: AppColors.red)
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.purple.opacity(0.18))
                    .frame(height: 1)
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.purple)
                            .frame(width: 4, height: 4)
                        Text("Tone arc captured every ~2s")
                            .font(AppFonts.bodyMedium(11))
                            .foregroundStyle(AppColors.text)
                    }
                    Spacer()
                    if arc.count >= 2 {
                        (
                            Text("Confidence ")
                                .font(AppFonts.body(11))
                                .foregroundStyle(AppColors.dim)
                            + Text("\(arrow) \(firstPct) → \(lastPct)")
                                .font(AppFonts.bodyMedium(11))
                                .foregroundStyle(deltaColor)
                        )
                    }
                }
                .padding(.vertical, 11)
                Rectangle()
                    .fill(AppColors.purple.opacity(0.18))
                    .frame(height: 1)
            }
            .padding(.bottom, 16)

            Button(action: onTapDetails) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppColors.purple.opacity(0.32))
                        Circle()
                            .stroke(AppColors.purple.opacity(0.65), lineWidth: 1)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.purple)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("See your full tone analysis")
                            .font(AppFonts.bodyBold(14))
                            .foregroundStyle(AppColors.text)
                        Text("Tone arc · peaks & dips · emotion breakdown")
                            .font(AppFonts.body(10.5))
                            .foregroundStyle(AppColors.sub)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.purple)
                }
                .padding(EdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 14))
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [AppColors.purple.opacity(0.24), AppColors.purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.purple.opacity(0.65), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.purple.opacity(0.45), lineWidth: 10)
                        .blur(radius: 12)
                        .blendMode(.plusLighter)
                        .mask(RoundedRectangle(cornerRadius: 14))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                AppColors.card
                RadialGradient(
                    colors: [AppColors.purple.opacity(0.22), AppColors.purple.opacity(0.06), .clear],
                    center: UnitPoint(x: 1.0, y: 0.0),
                    startRadius: 0,
                    endRadius: 260
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.purple.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: AppColors.purple.opacity(0.26), radius: 28, x: 0, y: 14)
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
            direction = "↑ improved"
            color = AppColors.teal
        } else if delta <= -0.05 {
            direction = "↓ declined"
            color = AppColors.red
        } else {
            direction = "→ steady"
            color = AppColors.sub
        }

        return HStack(spacing: 6) {
            Text("Confidence arc:")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
            Text("\(direction) · \(String(format: "%.0f%%", first * 100)) → \(String(format: "%.0f%%", last * 100))")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(color)
        }
    }

    private var teaserCard: some View {
        ZStack {
            mockCardContent
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: 5)
                .allowsHitTesting(false)

            Color.black.opacity(0.45)

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
                    .foregroundStyle(AppColors.onGold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppColors.gold)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(AppColors.card)
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
        .accessibilityHidden(true)
    }

    private var proLabel: some View {
        Text("PRO")
            .font(AppFonts.bodyBold(9))
            .foregroundStyle(AppColors.onGold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppColors.gold)
            .clipShape(Capsule())
    }
}
