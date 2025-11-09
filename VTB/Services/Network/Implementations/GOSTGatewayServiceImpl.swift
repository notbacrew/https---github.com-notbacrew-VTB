
import Foundation
import Security

final class GOSTGatewayServiceImpl: GOSTGatewayService {
    let bankId: String
    let bankName: String

    private let apiClient: APIClient
    private let securityManager = SecurityManager.shared
    private let oauthService = OAuthService.shared
    private let tokenManager = TokenManager.shared
    private let bankInfo: BankInfo

    init(bankInfo: BankInfo, apiClient: APIClient = APIClient()) {
        self.bankInfo = bankInfo
        self.bankId = bankInfo.id
        self.bankName = bankInfo.name
        self.apiClient = apiClient
    }

    private var gostBaseURL: URL {

        return URL(string: "https://api.gost.bankingapi.ru:8443")!
    }

    private func buildGOSTURL(path: String) -> URL {

        let basePath = "/api/rb/rewardsPay/hackathon/v1"
        let fullPath = basePath + path
        return gostBaseURL.appendingPathComponent(fullPath)
    }

    func getAccounts() async throws -> [AccountResponse] {

        let url = buildGOSTURL(path: "/accounts")

        var request = URLRequest(url: url)
        try signRequest(&request)

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: AccountsListResponse.self
        ).accounts
    }

    func getBalance(accountId: String) async throws -> BalanceResponse {
        let url = buildGOSTURL(path: "/accounts/\(accountId)/balance")

        var request = URLRequest(url: url)
        try signRequest(&request)

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: BalanceResponse.self
        )
    }

    func getTransactions(
        accountId: String,
        fromDate: Date?,
        toDate: Date?,
        limit: Int?
    ) async throws -> [TransactionResponse] {
        var urlComponents = URLComponents(
            url: buildGOSTURL(path: "/accounts/\(accountId)/transactions"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = []
        if let fromDate = fromDate {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "from_date", value: formatter.string(from: fromDate)))
        }
        if let toDate = toDate {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "to_date", value: formatter.string(from: toDate)))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        try signRequest(&request)

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: TransactionsListResponse.self
        ).transactions
    }

    func getCardInfo(cardId: String) async throws -> CardResponse {
        let url = buildGOSTURL(path: "/cards/\(cardId)")

        var request = URLRequest(url: url)
        try signRequest(&request)

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: CardResponse.self
        )
    }

    func checkConnection() async throws -> Bool {
        do {
            _ = try await getAccounts()
            return true
        } catch {
            return false
        }
    }

    func getPublicBankInfo() async throws -> PublicBankInfo {

        let gostURL = buildGOSTURL(path: "/banks/\(bankId)/public")

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: gostURL,
            headers: headers,
            responseType: PublicBankInfo.self
        )
    }

    func signRequest(_ request: inout URLRequest) throws {

        try securityManager.signRequest(&request, with: bankId)
    }

    func validateGOSTCertificate(_ certificate: SecCertificate) -> Bool {
        return securityManager.validateCertificate(certificate, forHost: bankInfo.baseURL.host ?? "")
    }

    private func getAuthHeaders() async throws -> [String: String] {

        if let existingToken = try? tokenManager.getAccessToken(forBank: bankId),
           !tokenManager.needsRefresh(forBank: bankId) {
            return [
                "Authorization": "Bearer \(existingToken)",
                "Content-Type": "application/json",
                "Accept": "application/json"
            ]
        }

        let clientId = bankInfo.oauthConfiguration.clientId
        guard let clientSecret = bankInfo.oauthConfiguration.clientSecret else {
            throw APIError.unauthorized
        }

        let tokenResponse = try await oauthService.getBankToken(
            bankId: bankId,
            clientId: clientId,
            clientSecret: clientSecret,
            baseURL: bankInfo.baseURL,
            isGOST: true
        )

        return [
            "Authorization": "Bearer \(tokenResponse.accessToken)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}

private struct AccountsListResponse: Codable {
    let accounts: [AccountResponse]
}

private struct TransactionsListResponse: Codable {
    let transactions: [TransactionResponse]
}
