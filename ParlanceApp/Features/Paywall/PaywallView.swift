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

    private let benefits: [String] = [
        "Pitch, Keynote, Debate, Storytelling, Negotiation, Networking. Six more modes.",
        "Tone analysis. See when your delivery loses energy.",
        "Advanced and Expert difficulty. Real-stakes prompts.",
        "Unlimited sessions per day."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    benefitsSection
                    trustLine
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
        .task { await loadProduct() }
        .alert("Couldn't start your subscription.", isPresented: $showErrorAlert) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text("Check your connection and try again.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("The full coach.")
                .font(AppFonts.display(34))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
            Text("Parlance Pro")
                .font(AppFonts.bodyBold(11))
                .foregroundStyle(AppColors.sub)
                .kerning(1.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var benefitsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Circle()
                        .fill(AppColors.gold)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
                    Text(line)
                        .font(AppFonts.body(15))
                        .foregroundStyle(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                if index < benefits.count - 1 {
                    Divider().background(AppColors.border)
                }
            }
        }
        .cardStyle(padding: 18)
    }

    private var trustLine: some View {
        Text("We transcribe locally. Audio is deleted after each session.")
            .font(AppFonts.body(12))
            .foregroundStyle(AppColors.sub)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    private var priceSection: some View {
        VStack(spacing: 4) {
            Text(product?.displayPrice ?? "$4.99")
                .font(AppFonts.bodyBold(20))
                .foregroundStyle(AppColors.text)
            Text("per month · cancel anytime")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
        }
    }

    private var ctaSection: some View {
        PrimaryButton(
            title: "Start Pro · \(product?.displayPrice ?? "$4.99")/mo",
            isLoading: isPurchasing,
            isEnabled: !isRestoring
        ) {
            Task { await purchase() }
        }
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
        VStack(spacing: 10) {
            Text("\(product?.displayPrice ?? "$4.99")/month, auto-renewing. Cancel at least 24 hours before the renewal date in App Store Settings or it will renew automatically.")
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: URL(string: "https://theparlance.app/terms")!)
                Text("·").foregroundStyle(AppColors.dim)
                Link("Privacy Policy", destination: URL(string: "https://theparlance.app/privacy")!)
            }
            .font(AppFonts.bodyMedium(11))
            .foregroundStyle(AppColors.sub)
        }
    }

    // MARK: - Actions

    private func loadProduct() async {
        let products = try? await Product.products(for: [AppConstants.proProductID])
        product = products?.first
    }

    private func purchase() async {
        isPurchasing = true
        // If we're already Pro (e.g. sandbox/TestFlight auto-grant), skip the
        // StoreKit round-trip — it would error with "product not found" until
        // the subscription is configured in App Store Connect.
        if subscription.isPro {
            isPurchasing = false
            dismiss()
            return
        }
        do {
            try await subscription.purchase()
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
