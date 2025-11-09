
import Foundation
import CoreData

final class ForecastingService {
    static let shared = ForecastingService()

    private init() {}

    func forecastIncome(
        from transactions: [Transaction],
        period: ForecastPeriod
    ) -> ForecastResult {
        let incomeTransactions = transactions
            .filter { $0.isIncome && $0.statusEnum == .completed }

        guard !incomeTransactions.isEmpty else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let methods = [
            movingAverageMethod(transactions: incomeTransactions),
            trendBasedMethod(transactions: incomeTransactions),
            patternBasedMethod(transactions: incomeTransactions)
        ]

        let sumAmount = methods.map { $0.amount }.reduce(Decimal(0), +)
        let averageAmount = sumAmount / Decimal(methods.count)
        let averageConfidence = methods.map { $0.confidence }.reduce(0.0, +) / Double(methods.count)

        return ForecastResult(
            amount: averageAmount,
            confidence: averageConfidence,
            method: .combined
        )
    }

    func forecastExpenses(
        from transactions: [Transaction],
        period: ForecastPeriod
    ) -> ForecastResult {
        let expenseTransactions = transactions
            .filter { $0.isExpense && $0.statusEnum == .completed }

        guard !expenseTransactions.isEmpty else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let methods = [
            movingAverageMethod(transactions: expenseTransactions),
            trendBasedMethod(transactions: expenseTransactions),
            categoryBasedMethod(transactions: expenseTransactions)
        ]

        let sumAmount = methods.map { $0.amount }.reduce(Decimal(0), +)
        let averageAmount = sumAmount / Decimal(methods.count)
        let averageConfidence = methods.map { $0.confidence }.reduce(0.0, +) / Double(methods.count)

        return ForecastResult(
            amount: averageAmount,
            confidence: averageConfidence,
            method: .combined
        )
    }

    func forecastByCategory(
        from transactions: [Transaction],
        period: ForecastPeriod
    ) -> [CategoryForecast] {
        let expenseTransactions = transactions.filter { $0.isExpense }

        var categoryForecasts: [TransactionCategory: Decimal] = [:]

        let grouped = Dictionary(grouping: expenseTransactions) { $0.categoryEnum ?? .otherExpense }

        for (category, categoryTransactions) in grouped {
            let forecast = forecastExpenses(from: categoryTransactions, period: period)

            if categoryForecasts[category] == nil {
                categoryForecasts[category] = 0
            }
            categoryForecasts[category] = forecast.amount
        }

        return categoryForecasts.map { category, amount in
            CategoryForecast(
                category: category,
                forecastedAmount: amount,
                confidence: 0.7
            )
        }
    }

    private func movingAverageMethod(transactions: [Transaction]) -> ForecastResult {

        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let recentTransactions = transactions.filter {
            ($0.transactionDate ?? Date()) >= threeMonthsAgo
        }

        guard !recentTransactions.isEmpty else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentTransactions) { transaction in
            calendar.dateInterval(of: .month, for: transaction.transactionDate ?? Date())?.start ?? Date()
        }

        let monthlyTotals = grouped.values.map { transactions in
            transactions.reduce(Decimal(0)) { total, transaction in
                let amount = transaction.amount?.toDecimal ?? 0
                return total + amount
            }
        }

        guard !monthlyTotals.isEmpty else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let average = monthlyTotals.reduce(0, +) / Decimal(monthlyTotals.count)
        let confidence = min(Double(monthlyTotals.count) / 3.0, 1.0)

        return ForecastResult(amount: average, confidence: confidence, method: .movingAverage)
    }

    private func trendBasedMethod(transactions: [Transaction]) -> ForecastResult {

        let sortedTransactions = transactions.sorted { ($0.transactionDate ?? Date()) < ($1.transactionDate ?? Date()) }

        guard sortedTransactions.count >= 2 else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let recentTransactions = sortedTransactions.filter {
            ($0.transactionDate ?? Date()) >= sixMonthsAgo
        }

        guard recentTransactions.count >= 2 else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let calendar = Calendar.current
        var monthlyData: [(date: Date, amount: Decimal)] = []

        for transaction in recentTransactions {
            let monthStart = calendar.dateInterval(of: .month, for: transaction.transactionDate ?? Date())?.start ?? Date()

            let amount = transaction.amount?.decimalValue ?? 0
            if let existing = monthlyData.first(where: { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }) {
                let index = monthlyData.firstIndex(where: { $0.date == existing.date })!
                monthlyData[index].amount += amount
            } else {
                monthlyData.append((date: monthStart, amount: amount))
            }
        }

        monthlyData.sort { $0.date < $1.date }

        guard monthlyData.count >= 2 else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let n = Decimal(monthlyData.count)
        var sumX: Decimal = 0
        var sumY: Decimal = 0
        var sumXY: Decimal = 0
        var sumX2: Decimal = 0

        for (index, data) in monthlyData.enumerated() {
            let x = Decimal(index)
            let y = data.amount

            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let b = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let a = (sumY - b * sumX) / n

        let nextMonthIndex = Decimal(monthlyData.count)
        let forecast = a + b * nextMonthIndex

        let confidence = min(Double(monthlyData.count) / 6.0, 0.9)

        return ForecastResult(amount: max(0, forecast), confidence: confidence, method: .trendAnalysis)
    }

    private func patternBasedMethod(transactions: [Transaction]) -> ForecastResult {

        let calendar = Calendar.current

        var patternAmounts: [Decimal] = []

        for transaction in transactions {
            guard let date = transaction.transactionDate else { continue }
            let dayOfMonth = calendar.component(.day, from: date)

            if dayOfMonth <= 5 || dayOfMonth >= 25 {
                let amount = transaction.amount?.toDecimal ?? 0
                patternAmounts.append(amount)
            }
        }

        guard !patternAmounts.isEmpty else {
            return ForecastResult(amount: 0, confidence: 0, method: .insufficientData)
        }

        let sum = patternAmounts.reduce(Decimal(0), +)
        let average = sum / Decimal(patternAmounts.count)
        let confidence = 0.6

        return ForecastResult(amount: average, confidence: confidence, method: .patternRecognition)
    }

    private func categoryBasedMethod(transactions: [Transaction]) -> ForecastResult {
        let transactionAnalyzer = TransactionAnalyzer.shared
        let topCategories = transactionAnalyzer.getTopExpenseCategories(from: transactions, limit: 5)

        let totalForecast = topCategories.reduce(0) { $0 + $1.total }
        let confidence = min(Double(topCategories.count) / 5.0, 0.8)

        return ForecastResult(amount: totalForecast, confidence: confidence, method: .categoryBased)
    }
}

struct ForecastResult {
    let amount: Decimal
    let confidence: Double
    let method: ForecastMethod
}

enum ForecastMethod {
    case movingAverage
    case trendAnalysis
    case patternRecognition
    case categoryBased
    case combined
    case insufficientData
}

enum ForecastPeriod: Hashable {
    case nextWeek
    case nextMonth
    case nextQuarter
    case nextYear

    var displayName: String {
        switch self {
        case .nextWeek: return "Следующая неделя"
        case .nextMonth: return "Следующий месяц"
        case .nextQuarter: return "Следующий квартал"
        case .nextYear: return "Следующий год"
        }
    }
}

struct CategoryForecast: Identifiable {
    let id = UUID()
    let category: TransactionCategory
    let forecastedAmount: Decimal
    let confidence: Double
}
