import SwiftUI
import UIKit

struct XPToastView: View {
    let xpEarned: Int
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            Text("+\(xpEarned) XP")
                .font(AppFonts.bodyBold(18))
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.gold.opacity(0.3), lineWidth: 1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityLabel("You earned \(xpEarned) XP")
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: "You earned \(xpEarned) XP")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = false
                        }
                    }
                }
        }
    }
}
