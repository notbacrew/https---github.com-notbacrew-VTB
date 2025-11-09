
import Foundation
import StoreKit
import Combine
import CoreData

enum SubscriptionTier: String {
    case free = "free"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free: return "Бесплатный"
        case .premium: return "Премиум"
        }
    }

    var maxBankConnections: Int {
        switch self {
        case .free: return 2
        case .premium: return Int.max
        }
    }

    var hasAdvancedForecasting: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }

    var hasExport: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }

    var hasCustomCategories: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }

    var isAdFree: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var currentTier: SubscriptionTier = .free
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false

    private let userDefaults = UserDefaults.standard
    private let tierKey = Constants.UserDefaultsKeys.subscriptionTier

    private init() {
        loadCurrentTier()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: ["vtb_premium_monthly", "vtb_premium_yearly"])
            availableProducts = products
        } catch {
            print("Ошибка загрузки продуктов: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            currentTier = .premium
            saveCurrentTier()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    func updateSubscriptionStatus() async {
        var isPremium = false

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productType == .autoRenewable {
                    isPremium = true
                    break
                }
            } catch {
                continue
            }
        }

        currentTier = isPremium ? .premium : .free
        saveCurrentTier()
    }

    func canUseFeature(_ feature: PremiumFeature, context: NSManagedObjectContext? = nil) -> Bool {
        switch feature {
        case .unlimitedBanks:
            guard let context = context else {

                return false
            }
            let currentConnections = getCurrentBankConnectionsCount(context: context)
            return currentTier.maxBankConnections > currentConnections
        case .advancedForecasting:
            return currentTier.hasAdvancedForecasting
        case .export:
            return currentTier.hasExport
        case .customCategories:
            return currentTier.hasCustomCategories
        case .adFree:
            return currentTier.isAdFree
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.unverified
        case .verified(let safe):
            return safe
        }
    }

    private func loadCurrentTier() {
        if let tierString = userDefaults.string(forKey: tierKey),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        }
    }

    private func saveCurrentTier() {
        userDefaults.set(currentTier.rawValue, forKey: tierKey)
    }

    func getCurrentBankConnectionsCount(context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<ConnectedBank> = ConnectedBank.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")

        do {
            let banks = try context.fetch(request)
            return banks.count
        } catch {
            print("Ошибка подсчета подключенных банков: \(error)")
            return 0
        }
    }
}

enum PremiumFeature {
    case unlimitedBanks
    case advancedForecasting
    case export
    case customCategories
    case adFree
}

enum SubscriptionError: LocalizedError {
    case unverified
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .unverified:
            return "Ошибка верификации покупки"
        case .purchaseFailed:
            return "Не удалось завершить покупку"
        case .productNotFound:
            return "Продукт не найден"
        }
    }
}
