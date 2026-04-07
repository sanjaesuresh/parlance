import SwiftUI

struct MetricCardView: View {
    let name: String
    let score: Int
    let tip: String

    private var scoreColor: Color {
        if score < 0 { return AppColors.sub }
        if score >= 8 { return AppColors.teal }
        if score >= 5 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: name + score
            HStack {
                Text(name)
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(AppColors.text)

                Spacer()

                if score >= 0 {
                    Text("\(score)/10")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(scoreColor)
                } else {
                    Text("—")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(AppColors.sub)
                }
            }

            // Progress bar
            if score >= 0 {
                ProgressBar(
                    pct: Double(score) / 10.0 * 100.0,
                    color: score < 5 ? AppColors.red : AppColors.gold,
                    height: 4
                )
                .padding(.top, 8)
            }

            // Tip text
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
