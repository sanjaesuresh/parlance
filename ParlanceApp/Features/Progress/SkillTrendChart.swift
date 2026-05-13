// Parlance/Features/Progress/SkillTrendChart.swift
//
// 5-column skill trend chart. Each column shows a delta-vs-all-time row, a
// gold-gradient bar whose height is `currentValue × 10%` of the wrap, the
// short metric label, and the numeric score. Spec: plan §4.5.2.

import SwiftUI

struct SkillTrendChart: View {
    let trends: [ProgressViewModel.SkillTrendItem]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(trends) { trend in
                trendColumn(for: trend)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .background(AppColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func trendColumn(for trend: ProgressViewModel.SkillTrendItem) -> some View {
        VStack(alignment: .center, spacing: 6) {
            deltaRow(for: trend)
            barWrap(for: trend)
            Text(trend.label)
                .font(AppFonts.body(9))
                .kerning(0.7)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.dim)
                .padding(.top, 2)
                .lineLimit(1)
            Text(formattedScore(trend.currentValue))
                .font(AppFonts.display(13))
                .foregroundStyle(AppColors.sub)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func deltaRow(for trend: ProgressViewModel.SkillTrendItem) -> some View {
        let isHidden = trend.deltaVsAllTime == nil
        let delta = trend.deltaVsAllTime ?? 0
        let isUp = delta >= 0
        let arrow = isUp ? "↑" : "↓"
        let color: Color = isUp ? AppColors.teal : AppColors.red

        HStack(spacing: 2) {
            Text(arrow)
                .font(AppFonts.bodyMedium(10))
                .foregroundStyle(color)
            Text(formattedDelta(delta))
                .font(AppFonts.bodyMedium(10))
                .foregroundStyle(color)
        }
        .frame(height: 14)
        .lineLimit(1)
        .opacity(isHidden ? 0 : 1)
    }

    @ViewBuilder
    private func barWrap(for trend: ProgressViewModel.SkillTrendItem) -> some View {
        let wrapWidth: CGFloat = 38
        let wrapHeight: CGFloat = 96
        let pct = max(0, min(1, trend.currentValue / 10.0))
        let fillHeight = wrapHeight * pct

        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.faint.opacity(0.35))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.gold, AppColors.goldDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: fillHeight)
                .shadow(color: AppColors.gold.opacity(0.18), radius: 11, x: 0, y: -8)
                .animation(
                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.35),
                    value: trend.currentValue
                )
        }
        .frame(width: wrapWidth, height: wrapHeight)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func formattedScore(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formattedDelta(_ delta: Double) -> String {
        // Round to 1 decimal place, sign-aware. Negative uses U+2212 minus sign.
        let abs = String(format: "%.1f", Swift.abs(delta))
        return delta >= 0 ? "+\(abs)" : "\u{2212}\(abs)"
    }
}
