// Parlance/Features/NoConnection/NoConnectionView.swift
import SwiftUI

struct NoConnectionView: View {
    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.card)
                        .frame(width: 120, height: 120)

                    Image(systemName: "wifi.slash")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppColors.gold.opacity(0.9))
                }

                VStack(spacing: 12) {
                    Text("No Internet Connection")
                        .font(AppFonts.display(24))
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)

                    Text("Parlance requires an internet connection to work. Check your connection and try again.")
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.red)
                        .frame(width: 8, height: 8)
                    Text("Offline")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.sub)
                }
                .padding(.bottom, 48)
            }
        }
    }
}
