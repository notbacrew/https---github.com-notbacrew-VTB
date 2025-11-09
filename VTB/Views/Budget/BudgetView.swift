
import SwiftUI
import CoreData

struct BudgetView: View {
    let context: NSManagedObjectContext
    @StateObject private var viewModel: BudgetViewModel
    @State private var showingCreateBudget = false

    init(context: NSManagedObjectContext) {
        self.context = context
        _viewModel = StateObject(wrappedValue: BudgetViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.budgets.isEmpty {
                    EmptyBudgetsView(onCreateBudget: {
                        showingCreateBudget = true
                    })
                } else {
                    ScrollView {
                        VStack(spacing: 20) {

                            if viewModel.budgets.count > 1 {
                                BudgetSelectorView(
                                    budgets: viewModel.budgets,
                                    selectedBudget: viewModel.selectedBudget,
                                    onSelect: { budget in
                                        Task {
                                            await viewModel.selectBudget(budget)
                                        }
                                    }
                                )
                            }

                            if let budget = viewModel.selectedBudget ?? viewModel.budgets.first {
                                BudgetOverviewCard(budget: budget)

                                if !viewModel.categoryBreakdown.isEmpty {
                                    CategoryBreakdownView(categories: viewModel.categoryBreakdown)
                                }

                                if let analysis = viewModel.spendingAnalysis {
                                    SpendingAnalysisView(analysis: analysis)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Бюджет")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateBudget = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingCreateBudget) {
                CreateBudgetView()
            }
            .onChange(of: showingCreateBudget) { oldValue, newValue in
                if !newValue {

                    Task {
                        await viewModel.loadData()
                    }
                }
            }
        }
    }
}

struct EmptyBudgetsView: View {
    let onCreateBudget: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Нет активных бюджетов")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Создайте бюджет, чтобы отслеживать свои расходы")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onCreateBudget) {
                Text("Создать бюджет")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct BudgetSelectorView: View {
    let budgets: [Budget]
    let selectedBudget: Budget?
    let onSelect: (Budget) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(budgets) { budget in
                    BudgetSelectorButton(
                        budget: budget,
                        isSelected: selectedBudget?.budgetId == budget.budgetId
                    ) {
                        onSelect(budget)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct BudgetSelectorButton: View {
    let budget: Budget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(budget.name ?? "Бюджет")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(budget.totalLimitDecimal.formattedCurrency())
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding()
            .frame(width: 150)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct BudgetOverviewCard: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(budget.name ?? "Бюджет")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if let period = budget.period {
                    Text(period)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Потрачено")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(budget.totalSpent.formattedCurrency())
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Лимит")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(budget.totalLimitDecimal.formattedCurrency())
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            ProgressView(value: min(budget.usagePercentage / 100.0, 1.0))
                .tint(budget.isExceeded ? .red : (budget.usagePercentage >= 80 ? .orange : .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)

            HStack {
                Text("\(Int(budget.usagePercentage))% использовано")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Осталось: \(budget.remaining.formattedCurrency())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(budget.isExceeded ? .red : .primary)
            }

            if budget.isExceeded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Бюджет превышен на \(abs(budget.remaining).formattedCurrency())")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct CategoryBreakdownView: View {
    let categories: [CategorySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Разбивка по категориям")
                .font(.headline)
                .padding(.horizontal)

            ForEach(categories) { category in
                CategoryRowView(category: category)
            }
        }
    }
}

struct CategoryRowView: View {
    let category: CategorySpending

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.category)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(Int(category.percentage))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(category.isExceeded ? .red : .secondary)
            }

            ProgressView(value: min(category.percentage / 100.0, 1.0))
                .tint(category.isExceeded ? .red : (category.percentage >= 80 ? .orange : .blue))

            HStack {
                Text("Потрачено: \(category.spent.formattedCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Лимит: \(category.limit.formattedCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if category.remaining > 0 {
                    Text("• Осталось: \(category.remaining.formattedCurrency())")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("• Превышен")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SpendingAnalysisView: View {
    let analysis: SpendingAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Анализ расходов")
                .font(.headline)

            VStack(spacing: 12) {
                AnalysisRow(
                    title: "Средний расход в день",
                    value: analysis.averageDaily.formattedCurrency(),
                    icon: "calendar"
                )

                if analysis.daysRemaining > 0 {
                    AnalysisRow(
                        title: "Дней до конца периода",
                        value: "\(analysis.daysRemaining)",
                        icon: "clock"
                    )

                    if let projected = analysis.projectedOverspend {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Возможное превышение: \(projected.formattedCurrency())")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }

                AnalysisRow(
                    title: "Всего транзакций",
                    value: "\(analysis.transactionsCount)",
                    icon: "list.bullet"
                )
            }

            if !analysis.topCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Топ категории расходов")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)

                    ForEach(Array(analysis.topCategories.prefix(5).enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30)

                            Text(item.category.displayName)
                                .font(.caption)

                            Spacer()

                            Text(item.total.formattedCurrency())
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("(\(item.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct AnalysisRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    BudgetView(context: PersistenceController.preview.container.viewContext)
}
