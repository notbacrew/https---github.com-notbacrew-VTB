
import Foundation

struct TransactionResponse: Codable, Identifiable {
    let id: String
    let accountId: String
    let amount: Decimal
    let currency: String
    let transactionDate: Date
    let description: String?
    let category: TransactionCategory?
    let merchantName: String?
    let type: TransactionType
    let status: TransactionStatus
    let bankId: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case amount
        case currency
        case transactionDate = "transaction_date"
        case description
        case category
        case merchantName = "merchant_name"
        case type
        case status
        case bankId = "bank_id"
    }
}

enum TransactionType: String, Codable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

enum TransactionCategory: String, Codable {

    case salary = "salary"
    case bonus = "bonus"
    case investment = "investment"
    case gift = "gift"
    case otherIncome = "other_income"

    case food = "food"
    case transport = "transport"
    case utilities = "utilities"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case health = "health"
    case education = "education"
    case bills = "bills"
    case subscriptions = "subscriptions"
    case otherExpense = "other_expense"

    var displayName: String {
        switch self {
        case .salary: return "Зарплата"
        case .bonus: return "Премия"
        case .investment: return "Инвестиции"
        case .gift: return "Подарки"
        case .otherIncome: return "Прочие доходы"
        case .food: return "Еда"
        case .transport: return "Транспорт"
        case .utilities: return "Коммунальные услуги"
        case .shopping: return "Покупки"
        case .entertainment: return "Развлечения"
        case .health: return "Здоровье"
        case .education: return "Образование"
        case .bills: return "Счета"
        case .subscriptions: return "Подписки"
        case .otherExpense: return "Прочие расходы"
        }
    }
}
