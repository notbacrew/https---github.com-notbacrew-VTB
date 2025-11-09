
import Foundation

struct BalanceResponse: Codable {
    let accountId: String
    let balance: Decimal
    let availableBalance: Decimal
    let currency: String
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case balance
        case availableBalance = "available_balance"
        case currency
        case lastUpdated = "last_updated"
    }
}
