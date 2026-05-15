import SwiftUI

// MARK: - Hero CTA

struct ProgressEmptyHeroCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GET STARTED")
                .font(AppFonts.bodyBold(10))
                .kerning(1.8)
                .foregroundStyle(AppColors.gold)

            Text("Record one session, watch this fill in.")
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Text("Daily Convo · 60 seconds · zero pressure.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
                .padding(.top, 8)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("Start a session")
                        .font(AppFonts.bodyBold(13))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppColors.onGold)
                .padding(.vertical, 11)
                .padding(.horizontal, 18)
                .background(AppColors.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityLabel("Start a session")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
        .background(
            ZStack {
                AppColors.card
                RadialGradient(
                    colors: [AppColors.gold.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 260
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.gold.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Section preview card

struct ProgressEmptyPreviewCard: View {
    let description: String

    var body: some View {
        Text(description)
            .font(AppFonts.body(12))
            .foregroundStyle(AppColors.sub)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            .background(AppColors.faint)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.border.opacity(0.7), lineWidth: 1)
            )
    }
}
