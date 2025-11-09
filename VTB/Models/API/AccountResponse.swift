
import Foundation

struct AccountResponse: Codable, Identifiable {
    let id: String
    let accountNumber: String
    let accountType: AccountType
    let currency: String
    let balance: Decimal?
    let availableBalance: Decimal?
    let status: AccountStatus
    let name: String?
    let openedDate: Date?
    let bankId: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountNumber = "account_number"
        case accountType = "account_type"
        case currency
        case balance
        case availableBalance = "available_balance"
        case status
        case name
        case openedDate = "opened_date"
        case bankId = "bank_id"
    }
}

enum AccountType: String, Codable {
    case current = "current"
    case savings = "savings"
    case deposit = "deposit"
    case credit = "credit"
    case investment = "investment"
}

enum AccountStatus: String, Codable {
    case active = "active"
    case blocked = "blocked"
    case closed = "closed"
    case pending = "pending"
}
