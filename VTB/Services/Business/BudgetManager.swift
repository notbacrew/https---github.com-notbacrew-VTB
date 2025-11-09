
import Foundation
import CoreData

final class BudgetManager {
    static let shared = BudgetManager()

    private let transactionAnalyzer = TransactionAnalyzer.shared
    private let notificationManager = NotificationManager.shared

    private init() {}

    func createBudget(
        name: String,
        totalLimit: Decimal,
        period: BudgetPeriod,
        context: NSManagedObjectContext
    ) -> Budget {
        let budget = Budget(context: context)
        budget.budgetId = UUID().uuidString
        budget.name = name
        budget.totalLimit = totalLimit as NSDecimalNumber
        budget.period = period.rawValue
        budget.createdDate = Date()

        let (startDate, endDate) = period.dates
        budget.startDate = startDate
        budget.endDate = endDate

        try? context.save()

        return budget
    }

    func createBudgetWithCategories(
        name: String,
        totalLimit: Decimal,
        period: BudgetPeriod,
        categories: [(category: TransactionCategory, limit: Decimal)],
        context: NSManagedObjectContext
    ) -> Budget {
        let budget = createBudget(name: name, totalLimit: totalLimit, period: period, context: context)

        for (category, limit) in categories {
            let budgetCategory = BudgetCategory(context: context)
            budgetCategory.categoryId = UUID().uuidString
            budgetCategory.name = category.displayName
            budgetCategory.limit = limit as NSDecimalNumber
            budgetCategory.categoryType = category.rawValue
            budgetCategory.spent = Decimal(0) as NSDecimalNumber
            budgetCategory.budget = budget
        }

        try? context.save()

        return budget
    }

    func updateBudgetSpending(
        _ budget: Budget,
        from transactions: [Transaction],
        context: NSManagedObjectContext
    ) {
        guard let categories = budget.categories as? Set<BudgetCategory> else {
            return
        }

        let periodTransactions = transactions.filter { transaction in
            guard let transactionDate = transaction.transactionDate,
                  let startDate = budget.startDate,
                  let endDate = budget.endDate else {
                return false
            }
            return transactionDate >= startDate && transactionDate <= endDate
        }

        for category in categories {
            guard let categoryType = category.categoryType,
                  let transactionCategory = TransactionCategory(rawValue: categoryType) else {
                continue
            }

            let categoryTransactions = periodTransactions.filter {
                $0.categoryEnum == transactionCategory && $0.isExpense
            }

            let totalSpent = categoryTransactions.reduce(Decimal(0)) { total, transaction in
                let amount = transaction.amount?.toDecimal ?? 0
                return total + amount
            }
            category.spent = totalSpent as NSDecimalNumber
        }

        try? context.save()

        checkBudgetAlerts(budget)
    }

    func updateAllBudgets(
        from transactions: [Transaction],
        context: NSManagedObjectContext
    ) {
        let request: NSFetchRequest<Budget> = Budget.fetchRequest()
        request.predicate = NSPredicate(format: "endDate >= %@", Date() as NSDate)

        guard let budgets = try? context.fetch(request) else {
            return
        }

        for budget in budgets {
            updateBudgetSpending(budget, from: transactions, context: context)
        }
    }

    func getActiveBudgets(context: NSManagedObjectContext) -> [Budget] {
        let request: NSFetchRequest<Budget> = Budget.fetchRequest()
        request.predicate = NSPredicate(format: "endDate >= %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.createdDate, ascending: false)]

        return (try? context.fetch(request)) ?? []
    }

    func getBudget(byId budgetId: String, context: NSManagedObjectContext) -> Budget? {
        let request: NSFetchRequest<Budget> = Budget.fetchRequest()
        request.predicate = NSPredicate(format: "budgetId == %@", budgetId)

        return try? context.fetch(request).first
    }

    private func checkBudgetAlerts(_ budget: Budget) {

        if budget.isExceeded {
            notificationManager.sendBudgetExceededNotification(
                budgetName: budget.name ?? "Бюджет",
                exceededBy: budget.totalSpent - budget.totalLimitDecimal
            )
        } else if budget.usagePercentage >= 80 {

            notificationManager.sendBudgetWarningNotification(
                budgetName: budget.name ?? "Бюджет",
                percentage: budget.usagePercentage
            )
        }

        guard let categories = budget.categories as? Set<BudgetCategory> else {
            return
        }

        for category in categories {
            if category.isExceeded {
                notificationManager.sendCategoryExceededNotification(
                    categoryName: category.name ?? "Категория",
                    budgetName: budget.name ?? "Бюджет"
                )
            }
        }
    }
}

enum BudgetPeriod: String {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .weekly: return "Неделя"
        case .monthly: return "Месяц"
        case .quarterly: return "Квартал"
        case .yearly: return "Год"
        case .custom: return "Произвольный"
        }
    }

    var dates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .weekly:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return (startOfWeek, endOfWeek)

        case .monthly:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (startOfMonth, endOfMonth)

        case .quarterly:
            let currentQuarter = (calendar.component(.month, from: now) - 1) / 3
            let startMonth = currentQuarter * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = startMonth
            components.day = 1
            let startOfQuarter = calendar.date(from: components)!
            let endOfQuarter = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: startOfQuarter)!
            return (startOfQuarter, endOfQuarter)

        case .yearly:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
            return (startOfYear, endOfYear)

        case .custom:
            return (now, calendar.date(byAdding: .month, value: 1, to: now)!)
        }
    }
}
