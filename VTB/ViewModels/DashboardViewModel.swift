
import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var totalBalance: Decimal = 0
    @Published var availableBalance: Decimal = 0
    @Published var recentTransactions: [Transaction] = []
    @Published var accounts: [BankAccount] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var incomeThisMonth: Decimal = 0
    @Published var expensesThisMonth: Decimal = 0
    @Published var savingsRate: Double = 0

    private let accountAggregator = AccountAggregator.shared
    private let transactionAnalyzer = TransactionAnalyzer.shared
    private let budgetManager = BudgetManager.shared
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {

            accounts = try await accountAggregator.getAllAccounts(context: context)

            totalBalance = accountAggregator.getAggregatedBalance(context: context)
            availableBalance = accountAggregator.getAggregatedAvailableBalance(context: context)

            recentTransactions = try accountAggregator.getAllTransactions(
                context: context,
                limit: 10
            )

            calculateMonthlyStats()

            updateBudgets()

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refresh() async {
        do {
            try await accountAggregator.syncAll(context: context)

            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calculateMonthlyStats() {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return
        }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "transactionDate >= %@", startOfMonth as NSDate)

        guard let allTransactions = try? context.fetch(request) else {
            return
        }

        incomeThisMonth = allTransactions
            .filter { $0.isIncome && $0.statusEnum == .completed }
            .reduce(Decimal(0)) { total, transaction in
                let amount = transaction.amount?.toDecimal ?? 0
                return total + amount
            }

        expensesThisMonth = allTransactions
            .filter { $0.isExpense && $0.statusEnum == .completed }
            .reduce(Decimal(0)) { total, transaction in
                let amount = transaction.amount?.toDecimal ?? 0
                return total + amount
            }

        if incomeThisMonth > 0 {
            let savings = incomeThisMonth - expensesThisMonth
            savingsRate = Double(truncating: NSDecimalNumber(decimal: savings / incomeThisMonth * 100))
        }
    }

    private func updateBudgets() {

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()

        guard let allTransactions = try? context.fetch(request) else {
            return
        }

        budgetManager.updateAllBudgets(from: allTransactions, context: context)
    }
}
