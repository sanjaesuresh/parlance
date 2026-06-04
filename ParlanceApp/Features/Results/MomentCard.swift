import SwiftUI

// MARK: - AI-scored moments (editorial)

struct AIMomentsCard: View {
    let bestQuote: String
    let bestReason: String
    let worstQuote: String
    let worstReason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
    }

    private func momentSection(
        label: String,
        symbol: String,
        quote: String,
        reason: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                Text(labelCased(label))
                    .font(AppFonts.bodyBold(10))
                    .kerning(0.4)
                    .foregroundStyle(accentColor)
            }

            Spacer().frame(height: 6)

            Text("\u{201C}\(quote)\u{201D}")
                .font(AppFonts.display(15))
                .italic()
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)

            if !reason.isEmpty {
                Spacer().frame(height: 4)
                Text(reason)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func labelCased(_ raw: String) -> String {
        raw.prefix(1).uppercased() + raw.dropFirst().lowercased()
    }
}

// MARK: - Rule-based moments (editorial)

struct MomentsCard: View {
    let bestTimestamp: String
    let bestText: String
    let worstTimestamp: String
    let worstText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
    }

    private func momentSection(
        label: String,
        symbol: String,
        timestamp: String,
        text: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                Text(labelCased(label))
                    .font(AppFonts.bodyBold(10))
                    .kerning(0.4)
                    .foregroundStyle(accentColor)
                Spacer()
                Text(timestamp)
                    .font(AppFonts.bodyMedium(10))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer().frame(height: 6)

            Text(text)
                .font(AppFonts.display(15))
                .italic()
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func labelCased(_ raw: String) -> String {
        raw.prefix(1).uppercased() + raw.dropFirst().lowercased()
    }
}
