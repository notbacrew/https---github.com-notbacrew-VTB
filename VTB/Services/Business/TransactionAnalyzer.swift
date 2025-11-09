
import Foundation
import CoreData

final class TransactionAnalyzer {
    static let shared = TransactionAnalyzer()

    private init() {}

    func categorizeTransaction(_ transaction: Transaction) -> TransactionCategory? {
        guard let description = transaction.transactionDescription?.lowercased(),
              let merchantName = transaction.merchantName?.lowercased() else {
            return nil
        }

        let searchText = "\(description) \(merchantName)"

        if matches(keywords: ["зарплата", "salary", "зп"], in: searchText) {
            return .salary
        }

        if matches(keywords: ["премия", "bonus"], in: searchText) {
            return .bonus
        }

        if matches(keywords: ["магазин", "store", "супермаркет", "supermarket", "продукты", "еда", "кафе", "ресторан", "restaurant", "cafe"], in: searchText) {
            return .food
        }

        if matches(keywords: ["транспорт", "transport", "метро", "metro", "автобус", "bus", "такси", "taxi", "uber", "яндекс.такси"], in: searchText) {
            return .transport
        }

        if matches(keywords: ["коммунальные", "utilities", "жкх", "электричество", "газ", "вода", "electricity", "gas", "water"], in: searchText) {
            return .utilities
        }

        if matches(keywords: ["покупка", "shopping", "магазин", "store", "интернет-магазин"], in: searchText) {
            return .shopping
        }

        if matches(keywords: ["кино", "movie", "театр", "theater", "развлечения", "entertainment", "игра", "game"], in: searchText) {
            return .entertainment
        }

        if matches(keywords: ["больница", "hospital", "клиника", "clinic", "врач", "doctor", "аптека", "pharmacy", "медицина"], in: searchText) {
            return .health
        }

        if matches(keywords: ["образование", "education", "курс", "course", "школа", "school", "университет", "university"], in: searchText) {
            return .education
        }

        if matches(keywords: ["подписка", "subscription", "netflix", "spotify", "яндекс.плюс", "youtube"], in: searchText) {
            return .subscriptions
        }

        if matches(keywords: ["счет", "bill", "платеж", "payment"], in: searchText) {
            return .bills
        }

        if transaction.isIncome {
            return .otherIncome
        }

        if transaction.isExpense {
            return .otherExpense
        }

        return nil
    }

    func updateTransactionCategory(_ transaction: Transaction, context: NSManagedObjectContext) {
        if transaction.category == nil {
            if let category = categorizeTransaction(transaction) {
                transaction.category = category.rawValue
                try? context.save()
            }
        }
    }

    func getAverageAmount(
        for category: TransactionCategory,
        in transactions: [Transaction],
        period: DateInterval? = nil
    ) -> Decimal {
        let filtered = transactions.filter {
            $0.categoryEnum == category &&
            (period == nil || (period!.contains($0.transactionDate ?? Date())))
        }

        guard !filtered.isEmpty else { return 0 }

        let total = filtered.reduce(Decimal(0)) { total, transaction in
            let amount = transaction.amount?.toDecimal ?? 0
            return total + amount
        }
        return total / Decimal(filtered.count)
    }

    func getTotalAmount(
        for category: TransactionCategory,
        in transactions: [Transaction],
        period: DateInterval? = nil
    ) -> Decimal {
        return transactions
            .filter {
                $0.categoryEnum == category &&
                (period == nil || (period!.contains($0.transactionDate ?? Date())))
            }
            .reduce(Decimal(0)) { total, transaction in
                let amount = transaction.amount?.toDecimal ?? 0
                return total + amount
            }
    }

    func getTopExpenseCategories(
        from transactions: [Transaction],
        limit: Int = 5
    ) -> [(category: TransactionCategory, total: Decimal, count: Int)] {
        let expenseTransactions = transactions.filter { $0.isExpense }

        var categoryTotals: [TransactionCategory: (total: Decimal, count: Int)] = [:]

        for transaction in expenseTransactions {
            guard let category = transaction.categoryEnum else { continue }

            let amount = transaction.amount?.toDecimal ?? 0
            if let existing = categoryTotals[category] {
                categoryTotals[category] = (
                    total: existing.total + amount,
                    count: existing.count + 1
                )
            } else {
                categoryTotals[category] = (total: amount, count: 1)
            }
        }

        return categoryTotals
            .map { (category: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    func detectAnomalies(in transactions: [Transaction]) -> [Transaction] {
        let expenseTransactions = transactions.filter { $0.isExpense }

        guard expenseTransactions.count > 5 else { return [] }

        let amounts = expenseTransactions.compactMap { $0.amount?.toDecimal }
        let sum = amounts.reduce(Decimal(0), +)
        let average = sum / Decimal(amounts.count)

        let threshold = average * 3

        return expenseTransactions.filter { transaction in
            let amount = transaction.amount?.toDecimal ?? 0
            return amount > threshold
        }
    }

    private func matches(keywords: [String], in text: String) -> Bool {
        return keywords.contains { text.contains($0.lowercased()) }
    }
}
