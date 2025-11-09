
import Foundation
import CoreData
import Combine

@MainActor
final class ForecastingViewModel: ObservableObject {
    @Published var incomeForecast: ForecastResult?
    @Published var expenseForecast: ForecastResult?
    @Published var categoryForecasts: [CategoryForecast] = []
    @Published var scenarioResults: [ScenarioResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: ForecastPeriod = .nextMonth

    private let context: NSManagedObjectContext
    private let forecastingService = ForecastingService.shared

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadForecast() async {
        isLoading = true
        defer { isLoading = false }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.transactionDate, ascending: false)]

        guard let transactions = try? context.fetch(request) else {
            errorMessage = "Не удалось загрузить транзакции"
            return
        }

        guard !transactions.isEmpty else {
            errorMessage = "Нет данных для прогнозирования. Подключите банки и синхронизируйте данные."
            return
        }

        incomeForecast = forecastingService.forecastIncome(
            from: transactions,
            period: selectedPeriod
        )

        expenseForecast = forecastingService.forecastExpenses(
            from: transactions,
            period: selectedPeriod
        )

        categoryForecasts = forecastingService.forecastByCategory(
            from: transactions,
            period: selectedPeriod
        ).sorted { $0.forecastedAmount > $1.forecastedAmount }

        calculateScenarios(income: incomeForecast?.amount ?? 0, expenses: expenseForecast?.amount ?? 0)

        errorMessage = nil
    }

    func updatePeriod(_ period: ForecastPeriod) async {
        selectedPeriod = period
        await loadForecast()
    }

    private func calculateScenarios(income: Decimal, expenses: Decimal) {
        var results: [ScenarioResult] = []

        let baseBalance = income - expenses
        results.append(ScenarioResult(
            name: "Базовый",
            description: "Прогноз на основе текущих данных",
            projectedBalance: baseBalance,
            income: income,
            expenses: expenses,
            confidence: ((incomeForecast?.confidence ?? 0) + (expenseForecast?.confidence ?? 0)) / 2
        ))

        let optimisticIncome = income * 1.1
        let optimisticExpenses = expenses * 0.95
        results.append(ScenarioResult(
            name: "Оптимистичный",
            description: "Увеличение доходов на 10%, снижение расходов на 5%",
            projectedBalance: optimisticIncome - optimisticExpenses,
            income: optimisticIncome,
            expenses: optimisticExpenses,
            confidence: 0.6
        ))

        let pessimisticIncome = income * 0.95
        let pessimisticExpenses = expenses * 1.1
        results.append(ScenarioResult(
            name: "Пессимистичный",
            description: "Снижение доходов на 5%, увеличение расходов на 10%",
            projectedBalance: pessimisticIncome - pessimisticExpenses,
            income: pessimisticIncome,
            expenses: pessimisticExpenses,
            confidence: 0.6
        ))

        let savingsExpenses = expenses * 0.8
        results.append(ScenarioResult(
            name: "Экономия",
            description: "Снижение расходов на 20% за счет оптимизации",
            projectedBalance: income - savingsExpenses,
            income: income,
            expenses: savingsExpenses,
            confidence: 0.7
        ))

        scenarioResults = results
    }
}

struct ScenarioResult: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let projectedBalance: Decimal
    let income: Decimal
    let expenses: Decimal
    let confidence: Double
}
