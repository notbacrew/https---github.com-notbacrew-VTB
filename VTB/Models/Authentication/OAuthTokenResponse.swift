
import Foundation

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

struct TokenInfo: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresAt: Date?
    let scope: String?

    var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }
        return expiresAt < Date()
    }

    var willExpireSoon: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }

        return expiresAt.timeIntervalSinceNow < 300
    }
}
