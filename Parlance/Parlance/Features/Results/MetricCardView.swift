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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)

                Text(tip)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .lineLimit(2)
            }

            Spacer()

            if score >= 0 {
                Text("\(score)/10")
                    .font(AppFonts.display(20))
                    .foregroundStyle(scoreColor)
            } else {
                Text("—")
                    .font(AppFonts.display(20))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .cardStyle()
    }
}
