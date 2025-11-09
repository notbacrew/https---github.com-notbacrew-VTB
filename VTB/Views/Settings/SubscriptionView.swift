
import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("Премиум подписка")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Разблокируйте все возможности приложения")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    CurrentTierCard(tier: subscriptionService.currentTier)

                    FeaturesList()

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if subscriptionService.availableProducts.isEmpty {
                        Text("Продукты временно недоступны")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 16) {
                            ForEach(subscriptionService.availableProducts, id: \.id) { product in
                                ProductCard(
                                    product: product,
                                    subscriptionService: subscriptionService
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Text("Восстановить покупки")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .disabled(isRestoring)
                    .padding(.horizontal)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Подписка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProducts()
            }
        }
    }

    private func loadProducts() async {
        isLoading = true
        await subscriptionService.loadProducts()
        isLoading = false
    }

    private func restorePurchases() async {
        isRestoring = true
        errorMessage = nil

        do {
            try await subscriptionService.restorePurchases()
            await subscriptionService.updateSubscriptionStatus()

            if subscriptionService.currentTier == .premium {
                errorMessage = nil
            } else {
                errorMessage = "Активных подписок не найдено"
            }
        } catch {
            errorMessage = "Ошибка восстановления: \(error.localizedDescription)"
        }

        isRestoring = false
    }
}

struct CurrentTierCard: View {
    let tier: SubscriptionTier

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Текущий план")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack {
                Text(tier.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if tier == .premium {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct FeaturesList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Что включено в Premium:")
                .font(.headline)
                .padding(.horizontal)

            FeatureRow(
                icon: "infinity",
                title: "Неограниченное количество банков",
                description: "Подключайте столько банков, сколько нужно"
            )

            FeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Продвинутое прогнозирование",
                description: "Детальные прогнозы доходов и расходов"
            )

            FeatureRow(
                icon: "square.and.arrow.up",
                title: "Экспорт данных",
                description: "Экспортируйте отчеты в PDF и другие форматы"
            )

            FeatureRow(
                icon: "tag.fill",
                title: "Настройка категорий",
                description: "Создавайте собственные категории транзакций"
            )

            FeatureRow(
                icon: "xmark.circle.fill",
                title: "Без рекламы",
                description: "Используйте приложение без отвлекающей рекламы"
            )
        }
        .padding(.vertical)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ProductCard: View {
    let product: Product
    let subscriptionService: SubscriptionService

    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)

                    if let subscription = product.subscription {
                        Text(periodDescription(for: subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Button(action: {
                Task {
                    await purchase()
                }
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Подписаться")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(product.id.contains("yearly") ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isPurchasing || subscriptionService.isPurchasing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func periodDescription(for period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return "\(period.value) день"
        case .week:
            return "\(period.value) недел\(period.value == 1 ? "я" : "и")"
        case .month:
            return "\(period.value) месяц\(period.value == 1 ? "" : "а")"
        case .year:
            return "\(period.value) год\(period.value == 1 ? "" : "а")"
        @unknown default:
            return "Подписка"
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil

        do {
            let success = try await subscriptionService.purchase(product)

            if !success {
                errorMessage = "Покупка была отменена"
                showError = true
            }
        } catch {
            errorMessage = "Ошибка покупки: \(error.localizedDescription)"
            showError = true
        }

        isPurchasing = false
    }
}

#Preview {
    SubscriptionView()
}
