// Parlance/Features/Results/MetricCardView.swift
import SwiftUI

struct MetricCardView: View {
    let name: String
    let description: String
    let score: Int            // 0-10, or -1 if unavailable
    let tip: String

    private var scoreColor: Color {
        if score < 0 { return AppColors.sub }
        if score >= 8 { return AppColors.teal }
        if score >= 5 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.text)
                    Text(description)
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                if score >= 0 {
                    Text("\(score * 10)%")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(scoreColor)
                } else {
                    Text("—")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(AppColors.sub)
                }
            }

            if score >= 0 {
                ProgressBar(
                    pct: Double(score) / 10.0 * 100.0,
                    color: score >= 8 ? AppColors.teal : score >= 5 ? AppColors.gold : AppColors.red,
                    height: 4
                )
                .padding(.top, 8)
            }

            if !tip.isEmpty {
                Text(tip)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .lineLimit(2)
                    .padding(.top, 7)
            }
        }
        .padding(15)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
