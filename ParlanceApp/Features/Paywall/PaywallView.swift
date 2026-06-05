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
                    toneHeroCard
                    everythingElseSection
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

    private var toneHeroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("VOCAL TONE")
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.6)
                    .foregroundStyle(AppColors.purple)
                Spacer()
                HStack(spacing: 5) {
                    Text("✦").font(.system(size: 11))
                    Text("PRO")
                        .font(AppFonts.bodyBold(9.5))
                        .kerning(1)
                }
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(AppColors.gold.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppColors.gold.opacity(0.28), lineWidth: 1)
                )
            }
            .padding(.bottom, 12)

            Text("Hear the energy behind your words.")
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            Text("Confidence, nervousness, enthusiasm — second-by-second, every session.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            paywallSparkline
                .frame(height: 42)
                .padding(.bottom, 14)

            VStack(spacing: 9) {
                paywallBar(label: "Enthusiasm", score: 0.68, color: AppColors.teal)
                paywallBar(label: "Determination", score: 0.54, color: AppColors.gold)
                paywallBar(label: "Nervousness", score: 0.22, color: AppColors.red)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                AppColors.card2
                RadialGradient(
                    colors: [AppColors.purple.opacity(0.30), AppColors.purple.opacity(0)],
                    center: UnitPoint(x: 0.95, y: 0.05),
                    startRadius: 4,
                    endRadius: 320
                )
                .allowsHitTesting(false)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.purple.opacity(0.55), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vocal tone analysis, Pro only. Hear the energy behind your words. Confidence, nervousness, and enthusiasm tracked second-by-second every session.")
    }

    private var paywallSparkline: some View {
        // Decorative purple curve — illustrative, not real data.
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts: [(CGFloat, CGFloat)] = [
                (0.00, 0.78), (0.10, 0.64), (0.20, 0.50), (0.32, 0.44),
                (0.45, 0.60), (0.55, 0.46), (0.65, 0.30), (0.75, 0.26),
                (0.85, 0.18), (1.00, 0.10)
            ]
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.0 * w, y: first.1 * h))
                    for pt in pts.dropFirst() {
                        p.addLine(to: CGPoint(x: pt.0 * w, y: pt.1 * h))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [AppColors.purple.opacity(0.40), AppColors.purple.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.0 * w, y: first.1 * h))
                    for pt in pts.dropFirst() {
                        p.addLine(to: CGPoint(x: pt.0 * w, y: pt.1 * h))
                    }
                }
                .stroke(
                    AppColors.purple,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

                Circle()
                    .fill(AppColors.purple)
                    .frame(width: 6, height: 6)
                    .position(x: w, y: 0.10 * h)
            }
        }
        .accessibilityHidden(true)
    }

    private func paywallBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(AppFonts.body(11.5))
                    .foregroundStyle(AppColors.sub)
                Spacer()
                Text("\(Int((score * 100).rounded()))%")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.border)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(score, 0), 1)), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private var everythingElseSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
                Text("EVERYTHING ELSE")
                    .font(AppFonts.bodyBold(9.5))
                    .kerning(1.4)
                    .foregroundStyle(AppColors.sub)
                    .fixedSize()
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            }
            comparisonTable
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

    @ViewBuilder
    private var ctaSection: some View {
        if subscription.isPro {
            subscribedPill
        } else {
            PrimaryButton(
                title: "Start Pro · \(product?.displayPrice ?? "$4.99")/mo",
                isLoading: isPurchasing,
                isEnabled: !isRestoring
            ) {
                Task { await purchase() }
            }
        }
    }

    private var subscribedPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("You're subscribed to Pro")
                .font(AppFonts.bodyBold(16))
        }
        .foregroundStyle(AppColors.onGold)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            LinearGradient(
                colors: [AppColors.cinnamon, AppColors.gold, AppColors.goldDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're subscribed to Parlance Pro.")
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
        // App Store Guideline 3.1.2(a) — auto-renewing subscription disclosure.
        // Must include: payment-at-confirmation, auto-renewal terms, renewal
        // window + price, and how to manage. Title (Parlance Pro), length
        // (monthly), and price are surfaced separately above; Terms + Privacy
        // links are below.
        VStack(spacing: 10) {
            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Your Parlance Pro subscription automatically renews for \(product?.displayPrice ?? "$4.99")/month unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage your subscription or turn off auto-renewal anytime in your Apple ID account settings.")
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: AppURLs.standardEULA)
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
