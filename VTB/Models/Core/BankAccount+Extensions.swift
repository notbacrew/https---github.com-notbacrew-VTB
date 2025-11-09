
import Foundation
import CoreData

extension BankAccount {

    static func createOrUpdate(
        from response: AccountResponse,
        bank: ConnectedBank,
        context: NSManagedObjectContext
    ) -> BankAccount {
        let request: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        request.predicate = NSPredicate(format: "accountId == %@ AND bank == %@", response.id, bank)

        let account = (try? context.fetch(request).first) ?? BankAccount(context: context)

        account.accountId = response.id
        account.accountNumber = response.accountNumber
        account.accountType = response.accountType.rawValue
        account.balance = (response.balance ?? 0) as NSDecimalNumber
        account.availableBalance = (response.availableBalance ?? 0) as NSDecimalNumber
        account.currency = response.currency
        account.name = response.name
        account.status = response.status.rawValue
        account.openedDate = response.openedDate
        account.lastSyncDate = Date()
        account.bank = bank

        return account
    }

    var accountTypeEnum: AccountType? {
        guard let typeString = accountType else { return nil }
        return AccountType(rawValue: typeString)
    }

    var statusEnum: AccountStatus? {
        guard let statusString = status else { return nil }
        return AccountStatus(rawValue: statusString)
    }
}
