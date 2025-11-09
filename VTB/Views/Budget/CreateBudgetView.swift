
import SwiftUI
import CoreData

struct CreateBudgetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var budgetName: String = ""
    @State private var totalLimit: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var selectedCategories: Set<TransactionCategory> = []
    @State private var categoryLimits: [TransactionCategory: Decimal] = [:]
    @State private var showingCategoryLimits = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    @StateObject private var subscriptionService = SubscriptionService.shared

    private let budgetManager = BudgetManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Основная информация") {
                    TextField("Название бюджета", text: $budgetName)

                    TextField("Общий лимит", text: $totalLimit)
                        .keyboardType(.decimalPad)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Готово") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }

                    Picker("Период", selection: $selectedPeriod) {
                        ForEach([BudgetPeriod.weekly, .monthly, .quarterly, .yearly], id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                }

                Section("Категории") {
                        if subscriptionService.canUseFeature(.customCategories, context: viewContext) || selectedCategories.isEmpty {
                        CategorySelectionView(
                            selectedCategories: $selectedCategories,
                            categoryLimits: $categoryLimits
                        )

                        if !selectedCategories.isEmpty {
                            Button("Настроить лимиты по категориям") {
                                showingCategoryLimits = true
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            Text("Настройка категорий доступна в Premium")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            NavigationLink("Premium") {
                                SubscriptionView()
                            }
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Новый бюджет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        Task {
                            await createBudget()
                        }
                    }
                    .disabled(!isValid || isCreating)
                }
            }
            .sheet(isPresented: $showingCategoryLimits) {
                CategoryLimitsView(
                    selectedCategories: selectedCategories,
                    categoryLimits: $categoryLimits
                )
            }
        }
    }

    private var isValid: Bool {
        !budgetName.isEmpty &&
        !totalLimit.isEmpty &&
        Decimal(string: totalLimit) != nil &&
        Decimal(string: totalLimit) ?? 0 > 0
    }

    private func createBudget() async {
        guard isValid else { return }

        isCreating = true
        errorMessage = nil

        guard let totalLimitDecimal = Decimal(string: totalLimit) else {
            errorMessage = "Неверный формат суммы"
            isCreating = false
            return
        }

        do {
            if selectedCategories.isEmpty {

                _ = budgetManager.createBudget(
                    name: budgetName,
                    totalLimit: totalLimitDecimal,
                    period: selectedPeriod,
                    context: viewContext
                )
                try viewContext.save()
            } else {

                if subscriptionService.canUseFeature(.customCategories, context: viewContext) {
                    let categories: [(category: TransactionCategory, limit: Decimal)]

                    if !categoryLimits.isEmpty {
                        categories = selectedCategories.compactMap { category in
                            guard let limit = categoryLimits[category] else { return nil }
                            return (category, limit)
                        }
                    } else {

                        let limitPerCategory = totalLimitDecimal / Decimal(selectedCategories.count)
                        categories = selectedCategories.map { ($0, limitPerCategory) }
                    }

                    _ = budgetManager.createBudgetWithCategories(
                        name: budgetName,
                        totalLimit: totalLimitDecimal,
                        period: selectedPeriod,
                        categories: categories,
                        context: viewContext
                    )
                } else {

                    _ = budgetManager.createBudget(
                        name: budgetName,
                        totalLimit: totalLimitDecimal,
                        period: selectedPeriod,
                        context: viewContext
                    )
                    try viewContext.save()
                    await MainActor.run {
                        dismiss()
                    }
                    return
                }
            }

            try viewContext.save()

            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Ошибка создания бюджета: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

struct CategorySelectionView: View {
    @Binding var selectedCategories: Set<TransactionCategory>
    @Binding var categoryLimits: [TransactionCategory: Decimal]

    var body: some View {
        ForEach(Array(TransactionCategory.allCases), id: \.self) { category in
            CategoryToggleRow(
                category: category,
                isSelected: selectedCategories.contains(category),
                onToggle: {
                    if selectedCategories.contains(category) {
                        selectedCategories.remove(category)
                        categoryLimits.removeValue(forKey: category)
                    } else {
                        selectedCategories.insert(category)
                    }
                }
            )
        }
    }
}

struct CategoryToggleRow: View {
    let category: TransactionCategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)

                Text(category.displayName)
                    .foregroundColor(.primary)

                Spacer()
            }
        }
    }
}

struct CategoryLimitsView: View {
    let selectedCategories: Set<TransactionCategory>
    @Binding var categoryLimits: [TransactionCategory: Decimal]
    @Environment(\.dismiss) private var dismiss

    @State private var tempLimits: [TransactionCategory: String] = [:]

    var body: some View {
        NavigationView {
            Form {
                ForEach(Array(selectedCategories), id: \.self) { category in
                    Section(category.displayName) {
                        TextField("Лимит", text: Binding(
                            get: { tempLimits[category] ?? "" },
                            set: { tempLimits[category] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .onChange(of: tempLimits[category]) { oldValue, newValue in
                            if let value = newValue, let decimal = Decimal(string: value) {
                                categoryLimits[category] = decimal
                            } else {
                                categoryLimits.removeValue(forKey: category)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Лимиты по категориям")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
}

extension TransactionCategory {
    static var allCases: [TransactionCategory] {
        return [
            .food, .transport, .shopping, .entertainment,
            .bills, .health, .education,
            .utilities, .subscriptions, .otherExpense
        ]
    }
}

extension Decimal {
    init?(string: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")

        if let number = formatter.number(from: string) {
            self = number.decimalValue
        } else {

            let simpleFormatter = NumberFormatter()
            simpleFormatter.numberStyle = .decimal
            simpleFormatter.locale = Locale(identifier: "en_US")

            if let number = simpleFormatter.number(from: string) {
                self = number.decimalValue
            } else {
                return nil
            }
        }
    }
}

#Preview {
    CreateBudgetView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
