
import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Ошибка запроса разрешения на уведомления: \(error)")
            return false
        }
    }

    private var isBudgetNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.budgetNotificationsEnabled) != nil ?
            UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.budgetNotificationsEnabled) :
            true
    }

    private var isTransactionNotificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.transactionNotificationsEnabled)
    }

    func sendBudgetExceededNotification(budgetName: String, exceededBy: Decimal) {
        guard isBudgetNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Превышен бюджет"
        content.body = "Бюджет '\(budgetName)' превышен на \(formatAmount(exceededBy))"
        content.sound = .default
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: "budget_exceeded_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendBudgetWarningNotification(budgetName: String, percentage: Double) {
        guard isBudgetNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Бюджет почти исчерпан"
        content.body = "Бюджет '\(budgetName)' использован на \(Int(percentage))%"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget_warning_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendCategoryExceededNotification(categoryName: String, budgetName: String) {
        guard isBudgetNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Превышен лимит категории"
        content.body = "Категория '\(categoryName)' в бюджете '\(budgetName)' превышена"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "category_exceeded_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendLargeTransactionNotification(amount: Decimal, description: String?) {
        guard isTransactionNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Крупная транзакция"
        content.body = "Зафиксирована транзакция на сумму \(formatAmount(amount))"
        if let description = description {
            content.body += ": \(description)"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "large_transaction_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendSyncSuccessNotification(bankName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Синхронизация завершена"
        content.body = "Данные из \(bankName) успешно обновлены"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync_success_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendSyncErrorNotification(bankName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Ошибка синхронизации"
        content.body = "Не удалось синхронизировать данные из \(bankName)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync_error_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₽"
    }
}
