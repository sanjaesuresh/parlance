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

    private struct ComparisonRow {
        let feature: String
        let detail: String?
        let free: Cell
        let pro: Cell

        enum Cell {
            case text(String)
            case check
            case dash
        }
    }

    private let rows: [ComparisonRow] = [
        .init(
            feature: "Practice modes",
            detail: "Interview, Pitch, Daily Convo, Impromptu, Explain, Networking",
            free: .text("6"),
            pro: .text("11")
        ),
        .init(
            feature: "Difficulty levels",
            detail: "Beginner through Expert",
            free: .text("1–6"),
            pro: .text("1–10")
        ),
        .init(
            feature: "Sessions per day",
            detail: nil,
            free: .text("\(AppConstants.freeSessionsPerDay)"),
            pro: .text("Unlimited")
        ),
        .init(
            feature: "Tone analysis",
            detail: "See when delivery loses energy",
            free: .dash,
            pro: .check
        ),
        .init(
            feature: "Filler word & pace analysis",
            detail: nil,
            free: .check,
            pro: .check
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headerSection
                    comparisonTable
                    priceSection
                    ctaSection
                    restoreButton
                    trustLine
                    legalText
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
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
        VStack(alignment: .leading, spacing: 12) {
            proPill
            Text("Everything in Parlance.")
                .font(AppFonts.display(30))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Here's what changes when you upgrade.")
                .font(AppFonts.bodyBold(11))
                .foregroundStyle(AppColors.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var proPill: some View {
        Text("PARLANCE PRO")
            .font(AppFonts.bodyBold(11))
            .kerning(0.9)
            .foregroundStyle(AppColors.onGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [AppColors.cinnamon, AppColors.gold, AppColors.goldDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                tableRow(row)
                if index < rows.count - 1 {
                    Divider().background(AppColors.border.opacity(0.55))
                }
            }
        }
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("FEATURE")
                .font(AppFonts.bodyBold(10))
                .kerning(1.2)
                .foregroundStyle(AppColors.sub)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("FREE")
                .font(AppFonts.bodyBold(10))
                .kerning(1.2)
                .foregroundStyle(AppColors.sub)
                .frame(width: 64)

            Text("PRO")
                .font(AppFonts.bodyBold(10))
                .kerning(1.2)
                .foregroundStyle(AppColors.onGold)
                .frame(width: 70, height: 22)
                .background(
                    LinearGradient(
                        colors: [AppColors.cinnamon, AppColors.gold, AppColors.goldDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.card2)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(AppColors.border),
            alignment: .bottom
        )
    }

    private func tableRow(_ row: ComparisonRow) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.feature)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                if let detail = row.detail {
                    Text(detail)
                        .font(AppFonts.body(11.5))
                        .foregroundStyle(AppColors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            cellView(row.free, isPro: false)
                .frame(width: 64)

            cellView(row.pro, isPro: true)
                .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func cellView(_ cell: ComparisonRow.Cell, isPro: Bool) -> some View {
        switch cell {
        case .text(let value):
            Text(value)
                .font(AppFonts.bodyBold(13.5))
                .foregroundStyle(isPro ? AppColors.goldDeep : AppColors.dim)
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isPro ? AppColors.goldDeep : AppColors.dim)
        case .dash:
            Text("—")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.dim)
        }
    }

    private var priceSection: some View {
        VStack(spacing: 4) {
            Text("\(product?.displayPrice ?? "$4.99") / month")
                .font(AppFonts.bodyBold(20))
                .foregroundStyle(AppColors.text)
            Text("cancel anytime")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
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

    private var trustLine: some View {
        Text("We transcribe on-device. Audio is deleted after each session.")
            .font(AppFonts.body(12))
            .foregroundStyle(AppColors.sub)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    private var legalText: some View {
        VStack(spacing: 10) {
            Text("\(product?.displayPrice ?? "$4.99")/month, auto-renewing. Cancel at least 24 hours before the renewal date in App Store Settings or it will renew automatically.")
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: AppURLs.terms)
                Text("·").foregroundStyle(AppColors.dim)
                Link("Privacy Policy", destination: AppURLs.privacy)
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
