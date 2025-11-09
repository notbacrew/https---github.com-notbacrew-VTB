
import Foundation
import CoreData

extension Transaction {

    static func create(
        from response: TransactionResponse,
        account: BankAccount,
        context: NSManagedObjectContext
    ) -> Transaction {
        let transaction = Transaction(context: context)

        transaction.transactionId = response.id
        transaction.amount = response.amount as NSDecimalNumber
        transaction.currency = response.currency
        transaction.transactionDate = response.transactionDate

        transaction.transactionDescription = response.description
        transaction.category = response.category?.rawValue
        transaction.merchantName = response.merchantName
        transaction.type = response.type.rawValue
        transaction.status = response.status.rawValue
        transaction.account = account

        return transaction
    }

    var typeEnum: TransactionType? {
        guard let typeString = type else { return nil }
        return TransactionType(rawValue: typeString)
    }

    var statusEnum: TransactionStatus? {
        guard let statusString = status else { return nil }
        return TransactionStatus(rawValue: statusString)
    }

    var categoryEnum: TransactionCategory? {
        guard let categoryString = category else { return nil }
        return TransactionCategory(rawValue: categoryString)
    }

    var isIncome: Bool {
        return typeEnum == .income
    }

    var isExpense: Bool {
        return typeEnum == .expense
    }
}
