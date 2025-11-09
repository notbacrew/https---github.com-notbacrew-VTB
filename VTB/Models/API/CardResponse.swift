
import Foundation

struct CardResponse: Codable, Identifiable {
    let id: String
    let accountId: String
    let cardNumber: String
    let cardType: CardType
    let expirationDate: String?
    let holderName: String?
    let status: CardStatus
    let bankId: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case cardNumber = "card_number"
        case cardType = "card_type"
        case expirationDate = "expiration_date"
        case holderName = "holder_name"
        case status
        case bankId = "bank_id"
    }
}

enum CardType: String, Codable {
    case debit = "debit"
    case credit = "credit"
    case prepaid = "prepaid"
}

enum CardStatus: String, Codable {
    case active = "active"
    case blocked = "blocked"
    case expired = "expired"
    case pending = "pending"
}
