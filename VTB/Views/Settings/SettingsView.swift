
import SwiftUI
import CoreData
import UIKit

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingBankConnection = false
    @State private var showingExportActivity = false
    @State private var exportURL: URL?
    @State private var exportErrorMessage: String?

    @State private var budgetNotificationsEnabled: Bool = true
    @State private var transactionNotificationsEnabled: Bool = false

    @StateObject private var subscriptionService = SubscriptionService.shared

    private let exportService = ExportService.shared

    var body: some View {
        NavigationView {
            List {
                Section("Подписка") {
                    NavigationLink(destination: SubscriptionView()) {
                        HStack {
                            Text("Премиум подписка")
                            Spacer()
                            if subscriptionService.currentTier == .premium {
                                Text("Активна")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text(subscriptionService.currentTier.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Банки") {
                    Button("Подключить банк") {
                        showingBankConnection = true
                    }
                }

                Section("Уведомления") {
                    Toggle("Уведомления о бюджете", isOn: $budgetNotificationsEnabled)
                        .onChange(of: budgetNotificationsEnabled) { oldValue, newValue in
                            saveNotificationSettings()
                        }

                    Toggle("Уведомления о транзакциях", isOn: $transactionNotificationsEnabled)
                        .onChange(of: transactionNotificationsEnabled) { oldValue, newValue in
                            saveNotificationSettings()
                        }
                }

                Section("Экспорт") {
                    Button("Экспорт данных в PDF") {
                        exportToPDF()
                    }
                    .disabled(!subscriptionService.canUseFeature(.export, context: viewContext))

                    Button("Экспорт в Excel (.csv)") {
                        exportToExcel()
                    }
                    .disabled(!subscriptionService.canUseFeature(.export, context: viewContext))

                    Button("Экспорт в Word (.rtf)") {
                        exportToWord()
                    }
                    .disabled(!subscriptionService.canUseFeature(.export, context: viewContext))

                    if !subscriptionService.canUseFeature(.export, context: viewContext) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            Text("Экспорт доступен в Premium")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("О приложении") {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showingBankConnection) {
                BankConnectionView(context: viewContext)
            }
            .sheet(isPresented: $showingExportActivity) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Ошибка экспорта", isPresented: .constant(exportErrorMessage != nil)) {
                Button("OK") {
                    exportErrorMessage = nil
                }
            } message: {
                if let error = exportErrorMessage {
                    Text(error)
                }
            }
            .onAppear {
                loadNotificationSettings()
            }
        }
    }

    private func loadNotificationSettings() {

        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.budgetNotificationsEnabled) != nil {
            budgetNotificationsEnabled = UserDefaults.standard.bool(
                forKey: Constants.UserDefaultsKeys.budgetNotificationsEnabled
            )
        } else {
            budgetNotificationsEnabled = true
        }

        transactionNotificationsEnabled = UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKeys.transactionNotificationsEnabled
        )

    }

    private func saveNotificationSettings() {
        UserDefaults.standard.set(
            budgetNotificationsEnabled,
            forKey: Constants.UserDefaultsKeys.budgetNotificationsEnabled
        )
        UserDefaults.standard.set(
            transactionNotificationsEnabled,
            forKey: Constants.UserDefaultsKeys.transactionNotificationsEnabled
        )
    }

    private func exportToPDF() {
        guard subscriptionService.canUseFeature(.export, context: viewContext) else {
            exportErrorMessage = "Экспорт доступен только в Premium версии"
            return
        }

        let accountsRequest: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        let transactionsRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        transactionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.transactionDate, ascending: false)]
        transactionsRequest.fetchLimit = 100

        let budgetsRequest: NSFetchRequest<Budget> = Budget.fetchRequest()

        do {
            let accounts = try viewContext.fetch(accountsRequest)
            let transactions = try viewContext.fetch(transactionsRequest)
            let budgets = try viewContext.fetch(budgetsRequest)

            let pdfURL = try exportService.exportToPDF(
                accounts: accounts,
                transactions: transactions,
                budgets: budgets,
                context: viewContext
            )

            exportURL = pdfURL
            showingExportActivity = true
        } catch {
            exportErrorMessage = "Не удалось создать PDF: \(error.localizedDescription)"
        }
    }

    private func exportToExcel() {
        guard subscriptionService.canUseFeature(.export, context: viewContext) else {
            exportErrorMessage = "Экспорт доступен только в Premium версии"
            return
        }

        let accountsRequest: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        let transactionsRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        transactionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.transactionDate, ascending: false)]
        transactionsRequest.fetchLimit = 100

        let budgetsRequest: NSFetchRequest<Budget> = Budget.fetchRequest()

        do {
            let accounts = try viewContext.fetch(accountsRequest)
            let transactions = try viewContext.fetch(transactionsRequest)
            let budgets = try viewContext.fetch(budgetsRequest)

            let excelURL = try exportService.exportToXLSX(
                accounts: accounts,
                transactions: transactions,
                budgets: budgets,
                context: viewContext
            )

            exportURL = excelURL
            showingExportActivity = true
        } catch {
            exportErrorMessage = "Не удалось создать Excel файл: \(error.localizedDescription)"
        }
    }

    private func exportToWord() {
        guard subscriptionService.canUseFeature(.export, context: viewContext) else {
            exportErrorMessage = "Экспорт доступен только в Premium версии"
            return
        }

        let accountsRequest: NSFetchRequest<BankAccount> = BankAccount.fetchRequest()
        let transactionsRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        transactionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.transactionDate, ascending: false)]
        transactionsRequest.fetchLimit = 100

        let budgetsRequest: NSFetchRequest<Budget> = Budget.fetchRequest()

        do {
            let accounts = try viewContext.fetch(accountsRequest)
            let transactions = try viewContext.fetch(transactionsRequest)
            let budgets = try viewContext.fetch(budgetsRequest)

            let wordURL = try exportService.exportToDOCX(
                accounts: accounts,
                transactions: transactions,
                budgets: budgets,
                context: viewContext
            )

            exportURL = wordURL
            showingExportActivity = true
        } catch {
            exportErrorMessage = "Не удалось создать Word файл: \(error.localizedDescription)"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
