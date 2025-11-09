
import Foundation
import CoreData

extension ConnectedBank {

    static func create(
        from bankInfo: BankInfo,
        context: NSManagedObjectContext
    ) -> ConnectedBank {
        let bank = ConnectedBank(context: context)
        bank.bankId = bankInfo.id
        bank.bankName = bankInfo.name
        bank.baseURL = bankInfo.baseURL.absoluteString
        bank.clientId = bankInfo.oauthConfiguration.clientId
        bank.connectedDate = Date()
        bank.isActive = true

        return bank
    }

    var baseURLValue: URL? {
        guard let urlString = baseURL else { return nil }
        return URL(string: urlString)
    }

    func getBankToken() async throws -> String? {
        guard let bankId = bankId,
              let clientId = clientId else {
            return nil
        }

        let keychainManager = KeychainManager.shared
        guard let clientSecret = try? keychainManager.getToken(
            forKey: Constants.KeychainKeys.clientSecret(forBank: bankId)
        ) else {
            return nil
        }

        guard let baseURL = baseURLValue else {
            return nil
        }

        if let existingToken = try? TokenManager.shared.getAccessToken(forBank: bankId),
           !TokenManager.shared.needsRefresh(forBank: bankId) {
            return existingToken
        }

        let isGOST = baseURL.absoluteString.contains("gost.bankingapi.ru") || baseURL.absoluteString.contains("api.gost.bankingapi.ru")

        let oauthService = OAuthService.shared
        let tokenResponse = try await oauthService.getBankToken(
            bankId: bankId,
            clientId: clientId,
            clientSecret: clientSecret,
            baseURL: baseURL,
            isGOST: isGOST
        )

        return tokenResponse.accessToken
    }

    func ensureConsent() async throws -> String? {

        if let existingConsentId = consentId {
            return existingConsentId
        }

        guard let clientId = clientId,
              let requestingBankId = requestingBankId,
              let baseURL = baseURLValue else {
            return nil
        }

        let bankToken = try await getBankToken()
        guard let token = bankToken else {
            return nil
        }

        let consentService = ConsentService.shared
        let consentResponse = try await consentService.createAccountConsent(
            bankToken: token,
            clientId: clientId,
            requestingBank: requestingBankId,
            baseURL: baseURL
        )

        consentId = consentResponse.consentId

        return consentResponse.consentId
    }
}
