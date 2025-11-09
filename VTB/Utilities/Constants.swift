
import Foundation

enum Constants {

    enum KeychainKeys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let idToken = "id_token"
        static let tokenExpiry = "token_expiry"
        static func clientSecret(forBank bankId: String) -> String {
            return "\(bankId)_client_secret"
        }
    }

    enum OAuth {
        static let redirectScheme = "vtb"
        static let redirectPath = "/oauth/callback"

        static var redirectURI: String {
            "\(redirectScheme)://\(redirectPath)"
        }
    }

    enum API {
        static let defaultTimeout: TimeInterval = 30.0
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 2.0
    }

    enum Sync {
        static let backgroundRefreshInterval: TimeInterval = 900
        static let cacheValidityDuration: TimeInterval = 300
    }

    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastSyncDate = "lastSyncDate"
        static let subscriptionTier = "subscriptionTier"
        static let biometricEnabled = "biometricEnabled"
        static let budgetNotificationsEnabled = "budgetNotificationsEnabled"
        static let transactionNotificationsEnabled = "transactionNotificationsEnabled"
    }
}
