import SwiftUI

struct XPBannerView: View {
    let xpEarned: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.gold)
                    .frame(width: 40, height: 40)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.onGold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Parlance")
                    .font(AppFonts.bodyBold(13))
                    .foregroundStyle(AppColors.text)
                Text("+\(xpEarned) XP earned")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }
}
