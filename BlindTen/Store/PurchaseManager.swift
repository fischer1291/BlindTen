import Foundation
import Observation
import StoreKit

/// StoreKit 2: one non-consumable Party Pack, no server.
///
/// Listens to `Transaction.updates`, checks `Transaction.currentEntitlements`
/// on launch and exposes `isPartyPackUnlocked`.
@MainActor
@Observable
final class PurchaseManager {
    enum Issue: Equatable {
        case failed
        case pending
        case unavailable
    }

    /// Starts from the last known state so the TV scene and the player
    /// limit are right before StoreKit has answered.
    private(set) var isPartyPackUnlocked = UserDefaults.standard.bool(forKey: PurchaseCache.unlockedKey)
    private(set) var product: Product?
    private(set) var isPurchasing = false
    private(set) var issue: Issue?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Call once at launch.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [PartyPack.productID]).first
        } catch {
            product = nil
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PartyPack.productID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPartyPackUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: PurchaseCache.unlockedKey)
        if unlocked {
            // A pending purchase (Ask to Buy) that went through.
            issue = nil
        }
    }

    func purchase() async {
        guard !isPurchasing else { return }
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            issue = .unavailable
            return
        }
        isPurchasing = true
        issue = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    issue = .failed
                }
            case .pending:
                issue = .pending
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            issue = .failed
        }
    }

    /// "Restore Purchases" (required by App Review).
    func restore() async {
        issue = nil
        do {
            try await AppStore.sync()
        } catch {
            issue = .failed
        }
        await refreshEntitlements()
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        // Unverified transactions are finished too, so they are not delivered
        // again on every launch; only verified ones unlock anything.
        switch update {
        case .verified(let transaction), .unverified(let transaction, _):
            await transaction.finish()
        }
        await refreshEntitlements()
    }
}

/// The last known unlock state. A hint only: `refreshEntitlements` always
/// replaces it with StoreKit's answer.
private enum PurchaseCache {
    static let unlockedKey = "partyPackUnlockedCache"
}
