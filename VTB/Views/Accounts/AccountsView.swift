
import SwiftUI
import CoreData

struct AccountsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BankAccount.accountId, ascending: true)],
        animation: .default
    ) private var accounts: FetchedResults<BankAccount>

    @State private var showingBankConnection = false
    @State private var isSyncing = false

    private let accountAggregator = AccountAggregator.shared

    var body: some View {
        NavigationView {
            List {
                if accounts.isEmpty {
                    Text("Нет подключенных счетов")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(accounts) { account in
                        AccountRowView(account: account)
                    }
                }
            }
            .navigationTitle("Счета")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingBankConnection = true
                    }) {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await syncAllAccounts()
                        }
                    }) {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isSyncing)
                }
            }
            .refreshable {
                await syncAllAccounts()
            }
            .sheet(isPresented: $showingBankConnection) {
                BankConnectionView(context: viewContext)
            }
        }
    }

    private func syncAllAccounts() async {
        isSyncing = true

        do {
            try await accountAggregator.syncAll(context: viewContext)
        } catch {
            print("Ошибка синхронизации: \(error)")
        }

        isSyncing = false
    }
}

struct AccountRowView: View {
    let account: BankAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(account.name ?? account.accountNumber ?? "Счет")
                    .font(.headline)

                Spacer()

                if let status = account.statusEnum {
                    Text(status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status == .active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            if let accountNumber = account.accountNumber {
                Text(accountNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Баланс:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text((account.balance?.toDecimal ?? 0).formattedCurrency(currencyCode: account.currency ?? "RUB"))
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            if let lastSyncDate = account.lastSyncDate {
                HStack {
                    Text("Обновлено:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastSyncDate.formatted(style: .short))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AccountsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
