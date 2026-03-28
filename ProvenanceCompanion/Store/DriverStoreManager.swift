import Foundation
import StoreKit

/// Manages StoreKit 2 purchases for DriverKit driver packs.
///
/// Products are non-consumable one-time purchases that unlock driver packs.
/// Entitlement is checked via `Transaction.currentEntitlements` — no server required.
@MainActor
@Observable
public final class DriverStoreManager {

    // MARK: - State

    public private(set) var products: [DriverStoreProduct] = []
    public private(set) var isLoading = false
    public private(set) var purchaseError: String?

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Lifecycle

    public init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Public API

    /// Load product metadata from App Store Connect.
    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        let ids = Set(DriverProductID.allCases.map(\.rawValue))
        do {
            let storeProducts = try await Product.products(for: ids)
            var result: [DriverStoreProduct] = []
            for storeProduct in storeProducts {
                guard let driverID = DriverProductID(rawValue: storeProduct.id) else { continue }
                let purchased = await isPurchased(storeProduct)
                result.append(DriverStoreProduct(id: driverID, product: storeProduct, isPurchased: purchased))
            }
            // Preserve enum ordering
            products = DriverProductID.allCases.compactMap { id in
                result.first { $0.id == id }
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Purchase a driver product.
    public func purchase(_ driverProduct: DriverStoreProduct) async {
        purchaseError = nil
        do {
            let result = try await driverProduct.product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts(for: transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // Transaction awaiting external confirmation (e.g. Ask to Buy)
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Restore completed transactions (required for non-consumable IAP).
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStates()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Returns true if the given product ID has been purchased.
    public func isPurchased(id: DriverProductID) -> Bool {
        products.first(where: { $0.id == id })?.isPurchased ?? false
    }

    /// Returns true if the all-access bundle is owned, or if the specific pack is owned.
    public func hasAccess(to id: DriverProductID) -> Bool {
        isPurchased(id: .allAccessBundle) || isPurchased(id: id)
    }

    // MARK: - Private

    private func isPurchased(_ product: Product) async -> Bool {
        guard let state = await product.currentEntitlement else { return false }
        do {
            let transaction = try checkVerified(state)
            return transaction.revocationDate == nil
        } catch {
            return false
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts(for: transaction)
                    await transaction.finish()
                } catch {
                    // Ignore unverified transactions
                }
            }
        }
    }

    @MainActor
    private func updatePurchasedProducts(for transaction: Transaction) async {
        guard let idx = products.firstIndex(where: { $0.product.id == transaction.productID }) else { return }
        products[idx].isPurchased = transaction.revocationDate == nil
    }

    @MainActor
    private func refreshPurchaseStates() async {
        var updated: [DriverStoreProduct] = []
        for product in products {
            let purchased = await isPurchased(product.product)
            updated.append(DriverStoreProduct(
                id: product.id,
                product: product.product,
                isPurchased: purchased
            ))
        }
        products = updated
    }
}
