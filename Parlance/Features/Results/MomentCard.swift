import SwiftUI

struct AIMomentCard: View {
    let label: String
    let quote: String
    let reason: String
    let labelColor: Color
    let bgColor: Color
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(labelColor)
                .kerning(0.5)

            Text("\u{201C}\(quote)\u{201D}")
                .font(AppFonts.body(11))
                .italic()
                .foregroundStyle(AppColors.dim)
                .lineLimit(3)
                .lineSpacing(2)

            if !reason.isEmpty {
                Text(reason)
                    .font(AppFonts.body(10))
                    .foregroundStyle(AppColors.dim)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

struct MomentCard: View {
    let label: String
    let timestamp: String
    let text: String
    let labelColor: Color
    let bgColor: Color
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(labelColor)
                .kerning(0.5)

            Text("\(timestamp) \u{2014} \(text)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .lineLimit(3)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
