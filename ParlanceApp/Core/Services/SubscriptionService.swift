// Parlance/Core/Services/SubscriptionService.swift
import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = true

    private var transactionUpdateTask: Task<Void, Never>?

    private init() {
        transactionUpdateTask = Task {
            await self.listenForTransactions()
        }
        Task { await refreshStatus() }
    }

    // Note: deinit is never called on this singleton, but cancelling the task
    // here is correct practice if the class is ever made non-singleton.
    deinit {
        transactionUpdateTask?.cancel()
    }

    // MARK: - Public

    func purchase() async throws {
        let products = try await Product.products(for: [AppConstants.proProductID])
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshStatus()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshStatus()
    }

    // MARK: - Internal (exposed for tests)

    #if DEBUG
    /// UI-test-only: synchronously mark the user Pro without going through
    /// StoreKit. Called by `UITestBootstrap` when `--ui-test-seed-pro` is
    /// set, so a test can tap the Real Life (or any Pro) mode tile before
    /// the async `refreshStatus()` has a chance to finish.
    func _uiTestSeedPro() {
        isPro = true
        isLoading = false
    }
    #endif

    func refreshStatus() async {
        isLoading = true
        #if DEBUG && targetEnvironment(simulator)
        isPro = true
        isLoading = false
        #else
        #if DEBUG
        if ProcessInfo.processInfo.environment["PARLANCE_PRO_OVERRIDE"] == "1" {
            isPro = true
            isLoading = false
            return
        }
        #endif
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConstants.proProductID,
               transaction.revocationDate == nil {
                hasPro = true
            }
        }
        isPro = hasPro
        isLoading = false
        #endif
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshStatus()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum SubscriptionError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Subscription product not found. Please try again later."
        case .failedVerification: return "Purchase verification failed."
        }
    }
}
