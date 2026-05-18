import SwiftUI

struct PromotionStatusPill: View {
    let status: PromotionStatus

    var body: some View {
        HStack(spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.bodyBold(14))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(borderColor.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(borderColor.opacity(0.15))
            Text(iconGlyph)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(borderColor)
        }
        .frame(width: 36, height: 36)
    }

    private var borderColor: Color {
        switch status {
        case .safe, .eligibleForPromotion, .atTop: AppColors.gold
        case .atRiskOfDemotion: AppColors.red
        }
    }

    private var iconGlyph: String {
        switch status {
        case .safe: "🛡"
        case .eligibleForPromotion: "↑"
        case .atRiskOfDemotion: "↓"
        case .atTop: "👑"
        }
    }

    private var title: String {
        switch status {
        case .safe: "You're in the safe zone"
        case .eligibleForPromotion(let xp): "\(xp) XP to promote"
        case .atRiskOfDemotion: "1 session to escape demotion"
        case .atTop: "You're at the top"
        }
    }

    private var subtitle: String {
        switch status {
        case .safe: "Keep practicing — no demotion risk"
        case .eligibleForPromotion: "Climb tiers before Monday"
        case .atRiskOfDemotion: "Stay above the bottom this week"
        case .atTop: "Hold the Diamond tier through Monday"
        }
    }
}
