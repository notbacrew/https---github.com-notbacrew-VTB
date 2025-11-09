
import Foundation

final class StandardOpenBankingService: BankAPIService {
    let bankId: String
    let bankName: String

    private let apiClient: APIClient
    private let oauthService = OAuthService.shared
    private let tokenManager = TokenManager.shared
    private let bankInfo: BankInfo

    private let requestingBankId: String?
    private let consentId: String?
    private let clientId: String?

    init(
        bankInfo: BankInfo,
        requestingBankId: String? = nil,
        consentId: String? = nil,
        clientId: String? = nil,
        apiClient: APIClient = APIClient()
    ) {
        self.bankInfo = bankInfo
        self.bankId = bankInfo.id
        self.bankName = bankInfo.name
        self.requestingBankId = requestingBankId
        self.consentId = consentId
        self.clientId = clientId
        self.apiClient = apiClient
    }

    func getAccounts() async throws -> [AccountResponse] {
        print("📊 Запрос списка счетов для банка \(bankName)...")
        
        var headers = try await getAuthHeaders()
        
        let possiblePaths = [
            "/accounts",
            "/api/v1/accounts",
            "/api/accounts"
        ]
        
        for path in possiblePaths {
            var urlComponents = URLComponents(
                url: bankInfo.baseURL.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            )

            if let clientId = clientId {
                urlComponents?.queryItems = [
                    URLQueryItem(name: "client_id", value: clientId)
                ]
            }

            guard let url = urlComponents?.url else {
                continue
            }
            
            print("🔍 Пробуем путь: \(path)")
            print("   URL: \(url.absoluteString)")

            do {
                let response = try await apiClient.get(
                    url: url,
                    headers: headers,
                    responseType: AccountsListResponse.self
                )

                print("✅ Получено счетов: \(response.accounts.count) (путь: \(path))")
                return response.accounts
            } catch APIError.forbidden {
                if path == "/accounts" {
                    print("   ⚠️ 403 для пути /accounts - требуется согласие")
                    print("   💡 Это правильный endpoint, но нужно создать согласие")
                }
                if path == possiblePaths.last {
                    throw error
                }
                print("   ❌ 403 для пути \(path), пробуем следующий...")
                continue
            } catch APIError.notFound {
                print("   ❌ 404 для пути \(path), пробуем следующий...")
                continue
            } catch {
                if path == possiblePaths.last {
                    throw error
                }
                print("   ⚠️ Ошибка для пути \(path): \(error), пробуем следующий...")
                continue
            }
        }
        
        throw APIError.notFound
    }

    func getBalance(accountId: String) async throws -> BalanceResponse {
        let url = bankInfo.baseURL.appendingPathComponent("/api/v1/accounts/\(accountId)/balances")

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
            url: bankInfo.baseURL.appendingPathComponent("/api/v1/accounts/\(accountId)/transactions"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = []

        if let fromDate = fromDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            queryItems.append(URLQueryItem(name: "from_booking_date_time", value: formatter.string(from: fromDate)))
        }
        if let toDate = toDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            queryItems.append(URLQueryItem(name: "to_booking_date_time", value: formatter.string(from: toDate)))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        queryItems.append(URLQueryItem(name: "page", value: "1"))

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        let headers = try await getAuthHeaders()

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: TransactionsListResponse.self
        ).transactions
    }

    func getCardInfo(cardId: String) async throws -> CardResponse {
        let url = bankInfo.baseURL.appendingPathComponent("/cards/\(cardId)")

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

    private func getAuthHeaders() async throws -> [String: String] {

        guard let accessToken = try tokenManager.getAccessToken(forBank: bankId) else {
            throw APIError.unauthorized
        }

        var headers: [String: String] = [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]

        if let requestingBankId = requestingBankId {
            headers["X-Requesting-Bank"] = requestingBankId
        }

        if let consentId = consentId {
            headers["X-Consent-Id"] = consentId
        }

        return headers
    }
}

private struct AccountsListResponse: Codable {
    let accounts: [AccountResponse]
}

private struct TransactionsListResponse: Codable {
    let transactions: [TransactionResponse]
}
