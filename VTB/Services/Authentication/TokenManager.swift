
import Foundation
import Combine

final class TokenManager {
    static let shared = TokenManager()

    private let keychainManager = KeychainManager.shared
    private var tokens: [String: TokenInfo] = [:]
    private let tokensQueue = DispatchQueue(label: "com.vtb.tokens", attributes: .concurrent)

    private init() {}

    func saveTokens(_ tokenResponse: OAuthTokenResponse, forBank bankId: String) throws {
        let expiresAt = tokenResponse.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }

        let tokenInfo = TokenInfo(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            idToken: tokenResponse.idToken,
            expiresAt: expiresAt,
            scope: tokenResponse.scope
        )

        tokensQueue.async(flags: .barrier) { [weak self] in
            self?.tokens[bankId] = tokenInfo
        }

        let keychainKey = keychainKey(forBank: bankId)
        try keychainManager.save(tokenInfo, forKey: keychainKey)
    }

    func getAccessToken(forBank bankId: String) throws -> String? {
        if let tokenInfo = getTokenInfo(forBank: bankId),
           !tokenInfo.isExpired {
            return tokenInfo.accessToken
        }

        let keychainKey = keychainKey(forBank: bankId)
        if let tokenInfo: TokenInfo = try keychainManager.get(TokenInfo.self, forKey: keychainKey),
           !tokenInfo.isExpired {
            tokensQueue.async(flags: .barrier) { [weak self] in
                self?.tokens[bankId] = tokenInfo
            }
            return tokenInfo.accessToken
        }

        return nil
    }

    func getRefreshToken(forBank bankId: String) throws -> String? {
        return getTokenInfo(forBank: bankId)?.refreshToken
    }

    func needsRefresh(forBank bankId: String) -> Bool {
        guard let tokenInfo = getTokenInfo(forBank: bankId) else {
            return true
        }
        return tokenInfo.isExpired || tokenInfo.willExpireSoon
    }

    func getTokenInfo(forBank bankId: String) -> TokenInfo? {
        return tokensQueue.sync {
            return tokens[bankId]
        }
    }

    func deleteTokens(forBank bankId: String) throws {
        tokensQueue.async(flags: .barrier) { [weak self] in
            self?.tokens.removeValue(forKey: bankId)
        }

        let keychainKey = keychainKey(forBank: bankId)
        try keychainManager.deleteToken(forKey: keychainKey)
    }

    func deleteAllTokens() throws {
        tokensQueue.async(flags: .barrier) { [weak self] in
            self?.tokens.removeAll()
        }
        try keychainManager.deleteAllTokens()
    }

    func loadTokensFromKeychain() throws {

    }

    private func keychainKey(forBank bankId: String) -> String {
        return "\(Constants.KeychainKeys.accessToken)_\(bankId)"
    }
}
