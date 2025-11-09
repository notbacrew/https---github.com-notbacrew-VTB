
import SwiftUI
import Charts
import CoreData

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @Environment(\.managedObjectContext) private var viewContext

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    BalanceCardView(
                        totalBalance: viewModel.totalBalance,
                        availableBalance: viewModel.availableBalance
                    )

                    MonthlyStatsView(
                        income: viewModel.incomeThisMonth,
                        expenses: viewModel.expensesThisMonth,
                        savingsRate: viewModel.savingsRate
                    )

                    RecentTransactionsView(transactions: viewModel.recentTransactions)

                    QuickActionsView()
                }
                .padding()
            }
            .navigationTitle("Главная")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadData()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

struct BalanceCardView: View {
    let totalBalance: Decimal
    let availableBalance: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Общий баланс")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(totalBalance.formattedCurrency())
                .font(.system(size: 32, weight: .bold))

            HStack {
                Text("Доступно:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(availableBalance.formattedCurrency())
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct MonthlyStatsView: View {
    let income: Decimal
    let expenses: Decimal
    let savingsRate: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                StatCardView(
                    title: "Доходы",
                    amount: income,
                    color: .green
                )

                StatCardView(
                    title: "Расходы",
                    amount: expenses,
                    color: .red
                )
            }

            HStack {
                Text("Процент сбережений")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(savingsRate))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(savingsRate >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

struct StatCardView: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(amount.formattedCurrency())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct RecentTransactionsView: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние транзакции")
                .font(.headline)

            if transactions.isEmpty {
                Text("Нет транзакций")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(transactions.prefix(5)), id: \.objectID) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionDescription ?? "Транзакция")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let date = transaction.transactionDate {
                    Text(date.formatted(style: .short))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text((transaction.amount?.toDecimal ?? 0).formattedCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые действия")
                .font(.headline)

            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Счета",
                    icon: "creditcard",
                    color: .blue
                )

                QuickActionButton(
                    title: "Бюджет",
                    icon: "chart.pie",
                    color: .orange
                )

                QuickActionButton(
                    title: "Прогноз",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

#Preview {
    DashboardView(context: PersistenceController.preview.container.viewContext)
}
