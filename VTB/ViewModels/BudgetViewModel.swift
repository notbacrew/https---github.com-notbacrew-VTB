
import Foundation
import CoreData
import Combine

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var selectedBudget: Budget?
    @Published var categoryBreakdown: [CategorySpending] = []
    @Published var spendingAnalysis: SpendingAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private let budgetManager = BudgetManager.shared
    private let transactionAnalyzer = TransactionAnalyzer.shared

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        budgets = budgetManager.getActiveBudgets(context: context)

        if let budget = selectedBudget ?? budgets.first {
            await loadBudgetAnalysis(budget)
        }
    }

    func selectBudget(_ budget: Budget) async {
        selectedBudget = budget
        await loadBudgetAnalysis(budget)
    }

    func refresh() async {

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        guard let transactions = try? context.fetch(request) else {
            return
        }

        budgetManager.updateAllBudgets(from: transactions, context: context)
        await loadData()
    }

    private func loadBudgetAnalysis(_ budget: Budget) async {
        guard let categories = budget.categories as? Set<BudgetCategory> else {
            categoryBreakdown = []
            spendingAnalysis = nil
            return
        }

        categoryBreakdown = categories.map { category in
            CategorySpending(
                category: category.name ?? "Неизвестно",
                limit: category.limitDecimal,
                spent: category.spentDecimal,
                remaining: category.remaining,
                percentage: category.usagePercentage,
                isExceeded: category.isExceeded,
                categoryType: category.categoryEnum
            )
        }.sorted { $0.spent > $1.spent }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        guard let transactions = try? context.fetch(request),
              let startDate = budget.startDate,
              let endDate = budget.endDate else {
            spendingAnalysis = nil
            return
        }

        let periodTransactions = transactions.filter { transaction in
            guard let date = transaction.transactionDate else { return false }
            return date >= startDate && date <= endDate && transaction.isExpense
        }

        let totalSpent = periodTransactions.reduce(Decimal(0)) { total, transaction in
            let amount = transaction.amount?.toDecimal ?? 0
            return total + amount
        }
        let averageDaily = calculateAverageDailySpending(
            transactions: periodTransactions,
            startDate: startDate,
            endDate: endDate
        )

        let topCategories = transactionAnalyzer.getTopExpenseCategories(
            from: periodTransactions,
            limit: 5
        )

        spendingAnalysis = SpendingAnalysis(
            totalSpent: totalSpent,
            totalLimit: budget.totalLimitDecimal,
            remaining: budget.remaining,
            averageDaily: averageDaily,
            daysRemaining: calculateDaysRemaining(endDate: endDate),
            topCategories: topCategories,
            transactionsCount: periodTransactions.count
        )
    }

    private func calculateAverageDailySpending(
        transactions: [Transaction],
        startDate: Date,
        endDate: Date
    ) -> Decimal {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1

        guard days > 0 else { return 0 }

        let total = transactions.reduce(Decimal(0)) { total, transaction in
            let amount = transaction.amount?.toDecimal ?? 0
            return total + amount
        }
        return total / Decimal(days)
    }

    private func calculateDaysRemaining(endDate: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard endDate > now else { return 0 }

        return calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
    }
}

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let limit: Decimal
    let spent: Decimal
    let remaining: Decimal
    let percentage: Double
    let isExceeded: Bool
    let categoryType: TransactionCategory?
}

struct SpendingAnalysis {
    let totalSpent: Decimal
    let totalLimit: Decimal
    let remaining: Decimal
    let averageDaily: Decimal
    let daysRemaining: Int
    let topCategories: [(category: TransactionCategory, total: Decimal, count: Int)]
    let transactionsCount: Int

    var usagePercentage: Double {
        guard totalLimit > 0 else { return 0 }
        return Double(truncating: NSDecimalNumber(decimal: totalSpent / totalLimit * 100))
    }

    var projectedOverspend: Decimal? {
        guard daysRemaining > 0 else { return nil }
        let projected = averageDaily * Decimal(daysRemaining)
        return projected > remaining ? projected - remaining : nil
    }
}
