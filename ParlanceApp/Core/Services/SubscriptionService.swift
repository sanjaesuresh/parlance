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
            print("[SubscriptionService] purchase: product not found for id=\(AppConstants.proProductID)")
            throw SubscriptionError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            print("[SubscriptionService] purchase: success id=\(transaction.productID) txn=\(transaction.id)")
            await transaction.finish()
            await refreshStatus()
        case .userCancelled:
            print("[SubscriptionService] purchase: user cancelled")
        case .pending:
            print("[SubscriptionService] purchase: pending (deferred — will arrive via Transaction.updates)")
        @unknown default:
            print("[SubscriptionService] purchase: unknown result")
        }
    }

    func restorePurchases() async {
        print("[SubscriptionService] restorePurchases: AppStore.sync()")
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
        #if DEBUG
        if ProcessInfo.processInfo.environment["PARLANCE_PRO_OVERRIDE"] == "1" {
            isPro = true
            isLoading = false
            return
        }
        // Honor the UI-test seed: the init() task races with bootstrap,
        // and without this guard StoreKit's empty entitlements would clobber
        // the seeded isPro=true back to false, locking Pro-only modes.
        if UITestBootstrap.isSeedProEnabled {
            isPro = true
            isLoading = false
            return
        }
        #endif
        var hasPro = false
        var entitlementCount = 0
        for await result in Transaction.currentEntitlements {
            entitlementCount += 1
            if case .verified(let transaction) = result,
               transaction.productID == AppConstants.proProductID,
               transaction.revocationDate == nil {
                hasPro = true
            }
        }
        let previous = isPro
        isPro = hasPro
        isLoading = false
        print("[SubscriptionService] refreshStatus: entitlements=\(entitlementCount) isPro=\(hasPro) (was=\(previous))")
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                print("[SubscriptionService] Transaction.updates: verified id=\(transaction.productID) txn=\(transaction.id)")
                await transaction.finish()
                await refreshStatus()
            case .unverified(_, let error):
                print("[SubscriptionService] Transaction.updates: unverified — \(error.localizedDescription)")
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
