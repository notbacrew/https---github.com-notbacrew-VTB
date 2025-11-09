
import Foundation

struct ConsentResponse: Codable {
    let requestId: String?
    let consentId: String
    let status: ConsentStatus
    let message: String?
    let createdAt: String?
    let autoApproved: Bool?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case consentId = "consent_id"
        case status
        case message
        case createdAt = "created_at"
        case autoApproved = "auto_approved"
    }
}

enum ConsentStatus: String, Codable {
    case approved = "approved"
    case pending = "pending"
    case rejected = "rejected"
    case revoked = "revoked"
}

struct ConsentRequest: Codable {
    let clientId: String
    let permissions: [String]
    let reason: String?
    let requestingBank: String
    let requestingBankName: String?

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case permissions
        case reason
        case requestingBank = "requesting_bank"
        case requestingBankName = "requesting_bank_name"
    }
}

struct ConsentStatusResponse: Codable {
    let consentId: String
    let status: ConsentStatus
    let creationDateTime: String?
    let statusUpdateDateTime: String?
    let permissions: [String]?
    let expirationDateTime: String?

    enum CodingKeys: String, CodingKey {
        case consentId = "consent_id"
        case status
        case creationDateTime = "creation_date_time"
        case statusUpdateDateTime = "status_update_date_time"
        case permissions
        case expirationDateTime = "expiration_date_time"
    }
}

final class ConsentService {
    static let shared = ConsentService()

    private let apiClient = APIClient()

    private init() {}

    func createAccountConsent(
        bankToken: String,
        clientId: String,
        requestingBank: String,
        baseURL: URL
    ) async throws -> ConsentResponse {
        let possiblePaths = [
            "/account-consents/request",
            "/api/v1/account-consents/request",
            "/api/v1/consents",
            "/consents"
        ]
        
        let request = ConsentRequest(
            clientId: clientId,
            permissions: ["ReadAccountsDetail", "ReadBalances", "ReadTransactionsDetail"],
            reason: "Агрегация счетов для HackAPI",
            requestingBank: requestingBank,
            requestingBankName: "Team 225 App"
        )

        let headers = [
            "Authorization": "Bearer \(bankToken)",
            "x-requesting-bank": requestingBank,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        for path in possiblePaths {
            let url = baseURL.appendingPathComponent(path)
            print("📝 Попытка создать согласие:")
            print("   URL: \(url.absoluteString)")
            print("   Client ID: \(clientId)")
            print("   Requesting Bank: \(requestingBank)")

            do {
                let response = try await apiClient.post(
                    url: url,
                    headers: headers,
                    body: request,
                    responseType: ConsentResponse.self
                )
                print("✅ Согласие создано через путь: \(path)")
                return response
            } catch APIError.notFound {
                if path == "/account-consents/request" {
                    print("   ⚠️ 404 для пути /account-consents/request")
                    print("   💡 Это правильный endpoint, но возможно 'Client team225 not found'")
                    print("   💡 Возможно, нужно использовать другой client_id или зарегистрировать клиента")
                }
                if path == possiblePaths.last {
                    throw error
                }
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

    func getConsentStatus(
        consentId: String,
        baseURL: URL
    ) async throws -> ConsentStatusResponse {
        let url = baseURL.appendingPathComponent("/api/v1/account-consents/\(consentId)")

        let headers = [
            "Accept": "application/json"
        ]

        return try await apiClient.get(
            url: url,
            headers: headers,
            responseType: ConsentStatusResponse.self
        )
    }

    func revokeConsent(
        consentId: String,
        baseURL: URL
    ) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/account-consents/\(consentId)")

        let headers = [
            "Accept": "application/json"
        ]

        let (_, response) = try await apiClient.performDataRequest(
            url: url,
            method: "DELETE",
            headers: headers,
            body: nil
        )

        guard (200...299).contains(response.statusCode) else {
            throw APIError.httpError(statusCode: response.statusCode, message: nil)
        }
    }
}
