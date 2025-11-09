
import SwiftUI
import CoreData
import Charts

struct ForecastingView: View {
    let context: NSManagedObjectContext
    @StateObject private var viewModel: ForecastingViewModel

    init(context: NSManagedObjectContext) {
        self.context = context
        _viewModel = StateObject(wrappedValue: ForecastingViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.errorMessage != nil && viewModel.incomeForecast == nil {
                    EmptyForecastView(message: viewModel.errorMessage ?? "Нет данных для прогнозирования")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {

                            PeriodPickerView(
                                selectedPeriod: $viewModel.selectedPeriod,
                                onPeriodChange: { period in
                                    Task {
                                        await viewModel.updatePeriod(period)
                                    }
                                }
                            )

                            if let incomeForecast = viewModel.incomeForecast,
                               let expenseForecast = viewModel.expenseForecast {
                                ForecastOverviewCard(
                                    income: incomeForecast,
                                    expenses: expenseForecast
                                )

                                if !viewModel.categoryForecasts.isEmpty {
                                    CategoryForecastView(forecasts: viewModel.categoryForecasts)
                                }

                                if !viewModel.scenarioResults.isEmpty {
                                    ScenarioPlanningView(scenarios: viewModel.scenarioResults)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Прогноз")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadForecast()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadForecast()
            }
            .refreshable {
                await viewModel.loadForecast()
            }
        }
    }
}

struct EmptyForecastView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Нет данных для прогноза")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct PeriodPickerView: View {
    @Binding var selectedPeriod: ForecastPeriod
    let onPeriodChange: (ForecastPeriod) -> Void

    var body: some View {
        Picker("Период", selection: $selectedPeriod) {
            ForEach([ForecastPeriod.nextWeek, .nextMonth, .nextQuarter, .nextYear], id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { oldValue, newValue in
            onPeriodChange(newValue)
        }
    }
}

struct ForecastOverviewCard: View {
    let income: ForecastResult
    let expenses: ForecastResult

    private var balance: Decimal {
        income.amount - expenses.amount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Прогноз на период")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Прогнозируемый баланс")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(balance.formattedCurrency())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(balance >= 0 ? .green : .red)
            }

            HStack(spacing: 20) {
                ForecastMetricView(
                    title: "Доходы",
                    amount: income.amount,
                    confidence: income.confidence,
                    color: .green
                )

                ForecastMetricView(
                    title: "Расходы",
                    amount: expenses.amount,
                    confidence: expenses.confidence,
                    color: .red
                )
            }

            ForecastChartView(income: income.amount, expenses: expenses.amount)

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Метод: \(income.method.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ForecastMetricView: View {
    let title: String
    let amount: Decimal
    let confidence: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(amount.formattedCurrency())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)

            HStack(spacing: 4) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 6, height: 6)
                Text("\(Int(confidence * 100))% уверенность")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confidenceColor: Color {
        if confidence >= 0.7 {
            return .green
        } else if confidence >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ForecastChartView: View {
    let income: Decimal
    let expenses: Decimal

    var body: some View {
        Chart {
            BarMark(
                x: .value("Тип", "Доходы"),
                y: .value("Сумма", NSDecimalNumber(decimal: income).doubleValue),
                width: .fixed(60)
            )
            .foregroundStyle(Color.green)
            .annotation(position: .top) {
                Text(income.formattedCurrency())
                    .font(.caption2)
            }

            BarMark(
                x: .value("Тип", "Расходы"),
                y: .value("Сумма", NSDecimalNumber(decimal: expenses).doubleValue),
                width: .fixed(60)
            )
            .foregroundStyle(Color.red)
            .annotation(position: .top) {
                Text(expenses.formattedCurrency())
                    .font(.caption2)
            }
        }
        .frame(height: 200)
        .padding(.vertical)
    }
}

struct CategoryForecastView: View {
    let forecasts: [CategoryForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Прогноз по категориям")
                .font(.headline)

            ForEach(forecasts.prefix(8)) { forecast in
                CategoryForecastRowView(forecast: forecast)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct CategoryForecastRowView: View {
    let forecast: CategoryForecast

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(forecast.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                    Text("\(Int(forecast.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(forecast.forecastedAmount.formattedCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }

    private var confidenceColor: Color {
        if forecast.confidence >= 0.7 {
            return .green
        } else if forecast.confidence >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ScenarioPlanningView: View {
    let scenarios: [ScenarioResult]
    @State private var selectedScenario: ScenarioResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Сценарии планирования")
                .font(.headline)

            Text("Сравните различные сценарии для планирования финансов")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(scenarios) { scenario in
                ScenarioCardView(
                    scenario: scenario,
                    isSelected: selectedScenario?.id == scenario.id
                ) {
                    selectedScenario = scenario
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ScenarioCardView: View {
    let scenario: ScenarioResult
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(scenario.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(scenario.projectedBalance.formattedCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scenario.projectedBalance >= 0 ? .green : .red)
                }

                Text(scenario.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Доходы")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(scenario.income.formattedCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Расходы")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(scenario.expenses.formattedCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 6, height: 6)
                        Text("\(Int(scenario.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var confidenceColor: Color {
        if scenario.confidence >= 0.7 {
            return .green
        } else if scenario.confidence >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

extension ForecastMethod {
    var displayName: String {
        switch self {
        case .movingAverage: return "Скользящая средняя"
        case .trendAnalysis: return "Трендовый анализ"
        case .patternRecognition: return "Анализ паттернов"
        case .categoryBased: return "По категориям"
        case .combined: return "Комбинированный"
        case .insufficientData: return "Недостаточно данных"
        }
    }
}

#Preview {
    ForecastingView(context: PersistenceController.preview.container.viewContext)
}
