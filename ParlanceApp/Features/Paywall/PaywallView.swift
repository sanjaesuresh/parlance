// Parlance/Features/Paywall/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    let source: String

    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var product: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("🎭", "All Practice Modes",        "Unlock all modes for every speaking scenario"),
        ("⚡", "Advanced & Expert Levels", "Access levels 7–10 for elite coaching"),
        ("🎙️", "Tone & Emotion Analysis",  "Audio analyzed by AI for emotion detection — see Privacy Policy"),
        ("∞",  "Unlimited Daily Sessions", "Practice as many times as you want, every day")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    benefitsSection
                    priceSection
                    ctaSection
                    restoreButton
                    legalText
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(AppColors.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dismiss") { dismiss() }
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.sub)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { AnalyticsService.paywallShown(source: source) }
        .task { await loadProduct() }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🎤")
                .font(.system(size: 52))
                .padding(.top, 8)
            Text("Parlance Pro")
                .font(AppFonts.display(30))
                .foregroundStyle(AppColors.text)
            Text("The full coaching experience.\nNothing held back.")
                .font(AppFonts.body(15))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                HStack(spacing: 14) {
                    Text(benefit.icon)
                        .font(.system(size: 22))
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title)
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                        Text(benefit.detail)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.teal)
                }
                .padding(.vertical, 14)
                if index < benefits.count - 1 {
                    Divider().background(AppColors.border)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var priceSection: some View {
        VStack(spacing: 4) {
            Text(product?.displayPrice ?? "$9.99")
                .font(AppFonts.display(36))
                .foregroundStyle(AppColors.gold)
            Text("per month · cancel anytime")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
        }
    }

    private var ctaSection: some View {
        Button {
            Task { await purchase() }
        } label: {
            ZStack {
                if isPurchasing {
                    SwiftUI.ProgressView().tint(.black)
                } else {
                    Text("Start Pro · \(product?.displayPrice ?? "$9.99")/mo")
                        .font(AppFonts.bodyBold(16))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppColors.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing || isRestoring)
    }

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            if isRestoring {
                SwiftUI.ProgressView().tint(AppColors.sub)
            } else {
                Text("Restore purchases")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .disabled(isPurchasing || isRestoring)
    }

    private var legalText: some View {
        Text("Subscription renews monthly unless cancelled at least 24 hours before the renewal date. Manage in App Store Settings.")
            .font(AppFonts.body(10))
            .foregroundStyle(AppColors.dim)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    // MARK: - Actions

    private func loadProduct() async {
        let products = try? await Product.products(for: [AppConstants.proProductID])
        product = products?.first
    }

    private func purchase() async {
        isPurchasing = true
        do {
            try await subscription.purchase()
            AnalyticsService.paywallConverted(productId: AppConstants.proProductID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true
        await subscription.restorePurchases()
        if subscription.isPro { dismiss() }
        isRestoring = false
    }
}
