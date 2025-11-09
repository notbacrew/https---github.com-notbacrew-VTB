
import SwiftUI
import CoreData

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingPageView(
                    title: "Добро пожаловать",
                    subtitle: "Управляйте всеми банками в одном приложении",
                    description: "Подключите свои банковские счета и карты для отслеживания финансов в реальном времени",
                    imageName: "creditcard.fill",
                    color: .blue
                )
                .tag(0)

                OnboardingPageView(
                    title: "Умный бюджет",
                    subtitle: "Автоматическое отслеживание расходов",
                    description: "Наш алгоритм автоматически категоризирует транзакции и помогает контролировать бюджет",
                    imageName: "chart.pie.fill",
                    color: .green
                )
                .tag(1)

                OnboardingPageView(
                    title: "Прогнозирование",
                    subtitle: "Планируйте финансы на будущее",
                    description: "Получайте прогнозы доходов и расходов на основе анализа ваших транзакций",
                    imageName: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
                .tag(2)

                OnboardingBankConnectionPageView(isPresented: $isPresented)
                    .tag(3)
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let color: Color

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: imageName)
                .font(.system(size: 80))
                .foregroundColor(color)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }
}

struct OnboardingBankConnectionPageView: View {
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: BankConnectionViewModel
    @State private var showingBankConnection = false

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented

        _viewModel = StateObject(wrappedValue: BankConnectionViewModel(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                Text("Безопасное подключение")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Используем Open Banking API")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("Ваши данные защищены стандартами безопасности и хранятся в зашифрованном виде")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }

            VStack(spacing: 16) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Button(action: {
                    showingBankConnection = true
                }) {
                    HStack {
                        if viewModel.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Подключить банк")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isConnecting)
                .padding(.horizontal, 40)

                Button(action: {
                    completeOnboarding()
                }) {
                    Text("Пропустить")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingBankConnection) {
            BankConnectionView(context: viewContext)
                .onDisappear {

                    if !viewModel.connectedBanks.isEmpty {
                        completeOnboarding()
                    }
                }
        }
        .onAppear {

            viewModel.loadConnectedBanks()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
        isPresented = false
    }
}
