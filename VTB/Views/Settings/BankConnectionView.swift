
import SwiftUI
import CoreData

struct BankConnectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BankConnectionViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: BankConnectionViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            List {
                if !viewModel.connectedBanks.isEmpty {
                    Section("Подключенные банки") {
                        ForEach(viewModel.connectedBanks, id: \.objectID) { bank in
                            ConnectedBankRowView(bank: bank) {
                                Task {
                                    await viewModel.disconnectBank(bank)
                                }
                            }
                        }
                    }
                }

                Section("Доступные банки") {
                    ForEach(viewModel.availableBanks, id: \.id) { bank in
                        AvailableBankRowView(
                            bank: bank,
                            isConnected: viewModel.isBankConnected(bank.id),
                            isConnecting: viewModel.isConnecting && viewModel.connectingBankId == bank.id
                        ) {
                            Task {
                                await viewModel.connectBank(bank)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Подключение банков")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
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

struct ConnectedBankRowView: View {
    let bank: ConnectedBank
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(bank.bankName ?? "Банк")
                    .font(.headline)

                if let connectedDate = bank.connectedDate {
                    Text("Подключен: \(connectedDate.formatted(style: .short))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onDisconnect) {
                Text("Отключить")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AvailableBankRowView: View {
    let bank: BankInfo
    let isConnected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack {

                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bank.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(bank.supportsGOST ? "GOST-шлюз поддерживается" : "Open Banking API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isConnecting {
                    ProgressView()
                } else if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isConnected || isConnecting)
    }
}

#Preview {
    BankConnectionView(context: PersistenceController.preview.container.viewContext)
}
