import SwiftUI

// MARK: - AI-scored moments (combined card)

struct AIMomentsCard: View {
    let bestQuote: String
    let bestReason: String
    let worstQuote: String
    let worstReason: String

    var body: some View {
        VStack(spacing: 0) {
            if !bestQuote.isEmpty {
                momentSection(
                    label: "BEST MOMENT",
                    symbol: "checkmark.circle.fill",
                    quote: bestQuote,
                    reason: bestReason,
                    accentColor: AppColors.teal
                )
            }

            if !bestQuote.isEmpty && !worstQuote.isEmpty {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            }

            if !worstQuote.isEmpty {
                momentSection(
                    label: "WEAKEST MOMENT",
                    symbol: "exclamationmark.circle.fill",
                    quote: worstQuote,
                    reason: worstReason,
                    accentColor: AppColors.red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func momentSection(
        label: String,
        symbol: String,
        quote: String,
        reason: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(label)
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(accentColor)
                    .kerning(0.6)
            }

            Text("\u{201C}\(quote)\u{201D}")
                .font(AppFonts.body(13))
                .italic()
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)

            if !reason.isEmpty {
                Text(reason)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.dim)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

// MARK: - Rule-based moments (combined card)

struct MomentsCard: View {
    let bestTimestamp: String
    let bestText: String
    let worstTimestamp: String
    let worstText: String

    var body: some View {
        VStack(spacing: 0) {
            if !bestText.isEmpty {
                momentSection(
                    label: "BEST MOMENT",
                    symbol: "checkmark.circle.fill",
                    timestamp: bestTimestamp,
                    text: bestText,
                    accentColor: AppColors.teal
                )
            }

            if !bestText.isEmpty && !worstText.isEmpty {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            }

            if !worstText.isEmpty {
                momentSection(
                    label: "WEAKEST MOMENT",
                    symbol: "exclamationmark.circle.fill",
                    timestamp: worstTimestamp,
                    text: worstText,
                    accentColor: AppColors.red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func momentSection(
        label: String,
        symbol: String,
        timestamp: String,
        text: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(label)
                    .font(AppFonts.bodyBold(10))
                    .foregroundStyle(accentColor)
                    .kerning(0.6)
                Spacer()
                Text(timestamp)
                    .font(AppFonts.bodyMedium(10))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(text)
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.dim)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
