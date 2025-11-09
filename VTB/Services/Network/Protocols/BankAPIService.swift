
import Foundation

protocol BankAPIService {

    var bankId: String { get }

    var bankName: String { get }

    func getAccounts() async throws -> [AccountResponse]

    func getBalance(accountId: String) async throws -> BalanceResponse

    func getTransactions(
        accountId: String,
        fromDate: Date?,
        toDate: Date?,
        limit: Int?
    ) async throws -> [TransactionResponse]

    func getCardInfo(cardId: String) async throws -> CardResponse

    func checkConnection() async throws -> Bool
}

struct BankInfo {
    let id: String
    let name: String
    let baseURL: URL
    let oauthConfiguration: OAuthConfiguration
    let supportsGOST: Bool
}
