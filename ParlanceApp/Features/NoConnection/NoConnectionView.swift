// Parlance/Features/NoConnection/NoConnectionView.swift
import SwiftUI

struct NoConnectionView: View {
    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppColors.sub)
                    Text("Offline")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.sub)
                }

                Text("Off the grid for now. We'll pick up where you left off when you're back.")
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
