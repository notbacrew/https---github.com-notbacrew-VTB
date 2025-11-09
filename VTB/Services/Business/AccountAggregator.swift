
import Foundation
import CoreData

final class AccountAggregator {
    static let shared = AccountAggregator()

    private let cacheManager = CacheManager.shared
    private let bankServiceFactory = BankServiceFactory.shared
    private let persistenceController = PersistenceController.shared
    private let notificationManager = NotificationManager.shared
    private let budgetManager = BudgetManager.shared

    private init() {}

    func getAllAccounts(context: NSManagedObjectContext) async throws -> [BankAccount] {
        let connectedBanks = try getConnectedBanks(context: context)
        var allAccounts: [BankAccount] = []

        for bank in connectedBanks {
            do {
                let accounts = try await syncAccounts(for: bank, context: context)
                allAccounts.append(contentsOf: accounts)
            } catch {

                print("Ошибка синхронизации банка \(bank.bankName ?? ""): \(error)")
            }
        }

        return allAccounts
    }

    func getAggregatedBalance(context: NSManagedObjectContext, currency: String = "RUB") -> Decimal {
        let request: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        request.predicate = NSPredicate(format: "currency == %@ AND status == %@", currency, AccountStatus.active.rawValue)

        guard let accounts = try? context.fetch(request) else {
            return 0
        }

        return accounts.reduce(Decimal(0)) { total, account in
            let balance = account.balance?.toDecimal ?? 0
            return total + balance
        }
    }

    func getAggregatedAvailableBalance(context: NSManagedObjectContext, currency: String = "RUB") -> Decimal {
        let request: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        request.predicate = NSPredicate(format: "currency == %@ AND status == %@", currency, AccountStatus.active.rawValue)

        guard let accounts = try? context.fetch(request) else {
            return 0
        }

        return accounts.reduce(Decimal(0)) { total, account in
            let availableBalance = account.availableBalance?.toDecimal ?? 0
            return total + availableBalance
        }
    }

    func syncAccounts(for bank: ConnectedBank, context: NSManagedObjectContext) async throws -> [BankAccount] {
        guard let bankId = bank.bankId,
              let bankName = bank.bankName,
              let baseURL = bank.baseURLValue else {
            throw AccountAggregatorError.invalidBankConfiguration
        }

        do {

            if !cacheManager.needsSync(forBank: bankId) {
                return try getCachedAccounts(for: bank, context: context)
            }

            var consentId = bank.consentId
            if consentId == nil {
                print("📋 Попытка создать согласие для банка \(bankName)...")
                let consentService = ConsentService.shared
                if let requestingBankId = bank.requestingBankId,
                   let clientId = bank.clientId {
                    if let bankToken = try TokenManager.shared.getAccessToken(forBank: bankId) {
                        do {
                            let consentResponse = try await consentService.createAccountConsent(
                                bankToken: bankToken,
                                clientId: clientId,
                                requestingBank: requestingBankId,
                                baseURL: baseURL
                            )

                            consentId = consentResponse.consentId
                            bank.consentId = consentId
                            try context.save()
                            print("✅ Согласие создано: \(consentResponse.consentId)")
                        } catch {
                            print("⚠️ Не удалось создать согласие: \(error). Продолжаем без согласия...")
                        }
                    } else {
                        print("⚠️ Пропуск создания согласия: токен не найден")
                    }
                } else {
                    print("⚠️ Пропуск создания согласия: отсутствуют requestingBankId или clientId")
                }
            }

            let oauthConfig = OAuthConfiguration(
                authorizationEndpoint: baseURL.appendingPathComponent("/auth/bank-token"),
                tokenEndpoint: baseURL.appendingPathComponent("/auth/bank-token"),
                clientId: bank.clientId ?? "",
                clientSecret: nil,
                scopes: OAuthConfiguration.defaultScopes,
                redirectURI: Constants.OAuth.redirectURI
            )

            let bankInfo = BankInfo(
                id: bankId,
                name: bankName,
                baseURL: baseURL,
                oauthConfiguration: oauthConfig,
                supportsGOST: false
            )

            let service = bankServiceFactory.createService(
                for: bankInfo,
                requestingBankId: bank.requestingBankId,
                consentId: consentId,
                clientId: bank.clientId
            )

            let accountsResponse = try await service.getAccounts()

            var savedAccounts: [BankAccount] = []
            for accountResponse in accountsResponse {
                let account = BankAccount.createOrUpdate(
                    from: accountResponse,
                    bank: bank,
                    context: context
                )
                savedAccounts.append(account)
            }

            cacheManager.setLastSyncDate(Date(), forBank: bankId)

            try context.save()

            notificationManager.sendSyncSuccessNotification(bankName: bankName)

            return savedAccounts
        } catch {

            notificationManager.sendSyncErrorNotification(bankName: bankName)
            throw error
        }
    }

    func syncTransactions(
        for account: BankAccount,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        context: NSManagedObjectContext
    ) async throws -> [Transaction] {
        guard let bank = account.bank,
              let bankId = bank.bankId,
              let accountId = account.accountId,
              let baseURL = bank.baseURLValue else {
            throw AccountAggregatorError.invalidAccountConfiguration
        }

        let defaultFromDate = fromDate ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())

        let oauthConfig = OAuthConfiguration(
            authorizationEndpoint: baseURL.appendingPathComponent("/auth/bank-token"),
            tokenEndpoint: baseURL.appendingPathComponent("/auth/bank-token"),
            clientId: bank.clientId ?? "",
            clientSecret: nil,
            scopes: OAuthConfiguration.defaultScopes,
            redirectURI: Constants.OAuth.redirectURI
        )

        let bankInfo = BankInfo(
            id: bankId,
            name: bank.bankName ?? "",
            baseURL: baseURL,
            oauthConfiguration: oauthConfig,
            supportsGOST: false
        )

        let service = bankServiceFactory.createService(
            for: bankInfo,
            requestingBankId: bank.requestingBankId,
            consentId: bank.consentId,
            clientId: bank.clientId
        )
        let transactionsResponse = try await service.getTransactions(
            accountId: accountId,
            fromDate: defaultFromDate,
            toDate: toDate ?? Date(),
            limit: 100
        )

        var savedTransactions: [Transaction] = []
        for transactionResponse in transactionsResponse {

            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "transactionId == %@", transactionResponse.id)

            if (try? context.fetch(request).first) == nil {
                let transaction = Transaction.create(
                    from: transactionResponse,
                    account: account,
                    context: context
                )
                savedTransactions.append(transaction)
            }
        }

        try context.save()

        return savedTransactions
    }

    func getAllTransactions(
        context: NSManagedObjectContext,
        fromDate: Date? = nil,
        limit: Int? = nil
    ) throws -> [Transaction] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.transactionDate, ascending: false)]

        if let fromDate = fromDate {
            request.predicate = NSPredicate(format: "transactionDate >= %@", fromDate as NSDate)
        }

        if let limit = limit {
            request.fetchLimit = limit
        }

        return try context.fetch(request)
    }

    func syncAll(context: NSManagedObjectContext) async throws {
        let connectedBanks = try getConnectedBanks(context: context)

        for bank in connectedBanks {

            let accounts = try await syncAccounts(for: bank, context: context)

            for account in accounts {
                _ = try await syncTransactions(for: account, context: context)
            }
        }

        let allTransactions = try getAllTransactions(context: context)
        budgetManager.updateAllBudgets(from: allTransactions, context: context)
    }

    private func getConnectedBanks(context: NSManagedObjectContext) throws -> [ConnectedBank] {
        let request: NSFetchRequest<ConnectedBank> = ConnectedBank.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        return try context.fetch(request)
    }

    private func getCachedAccounts(for bank: ConnectedBank, context: NSManagedObjectContext) throws -> [BankAccount] {
        let request: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        request.predicate = NSPredicate(format: "bank == %@", bank)
        return try context.fetch(request)
    }
}

enum AccountAggregatorError: LocalizedError {
    case invalidBankConfiguration
    case invalidAccountConfiguration
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBankConfiguration:
            return "Некорректная конфигурация банка"
        case .invalidAccountConfiguration:
            return "Некорректная конфигурация счета"
        case .syncFailed(let reason):
            return "Ошибка синхронизации: \(reason)"
        }
    }
}
