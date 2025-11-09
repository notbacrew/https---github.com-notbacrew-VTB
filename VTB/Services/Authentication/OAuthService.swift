
import Foundation
import AuthenticationServices
import Combine
import UIKit

struct OAuthConfiguration {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let clientId: String
    let clientSecret: String?
    let scopes: [String]
    let redirectURI: String

    static let defaultScopes = ["accounts", "transactions", "balance"]
}

enum OAuthResult {
    case success(OAuthTokenResponse)
    case failure(Error)
    case cancelled
}

final class OAuthService: NSObject {
    static let shared = OAuthService()

    private let tokenManager = TokenManager.shared
    private var continuation: CheckedContinuation<OAuthResult, Never>?
    private var currentSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    func getBankToken(
        bankId: String,
        clientId: String,
        clientSecret: String,
        baseURL: URL,
        isGOST: Bool = false
    ) async throws -> OAuthTokenResponse {
        let url: URL
        var request: URLRequest

        if isGOST {

            guard let gostAuthURL = URL(string: "https://auth.bankingapi.ru/auth/realms/kubernetes/protocol/openid-connect/token") else {
                throw OAuthError.invalidURL
            }
            url = gostAuthURL

            let bodyString = "grant_type=client_credentials&client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)&client_secret=\(clientSecret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientSecret)"

            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = bodyString.data(using: .utf8)

            print("🔐 Запрос GOST token через auth.bankingapi.ru:")
            print("   URL: \(url.absoluteString)")
            print("   Body: grant_type=client_credentials&client_id=\(clientId)&client_secret=***")
        } else {

            let authURL = baseURL.appendingPathComponent("/auth/bank-token")

            var urlComponents = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "client_secret", value: clientSecret)
            ]

            guard let standardURL = urlComponents?.url else {
                throw OAuthError.invalidURL
            }
            url = standardURL

            print("🔐 Запрос bank-token:")
            print("   URL: \(url.absoluteString.replacingOccurrences(of: clientSecret, with: "***"))")

            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

        }

        print("   Method: POST")
        print("   Client ID: \(clientId)")
        print("   Client Secret: \(clientSecret.prefix(4))...\(clientSecret.suffix(4))")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OAuthError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Запрос bank-token завершился с ошибкой: \(httpResponse.statusCode)")
                print("   Response: \(errorMessage)")

                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = errorJSON["error"] as? String {
                        print("   Error: \(error)")
                    }
                    if let errorDescription = errorJSON["error_description"] as? String {
                        print("   Description: \(errorDescription)")
                    }
                }

                if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    print("   ⚠️ Ошибка \(httpResponse.statusCode) (Bad Request/Unauthorized):")
                    if isGOST {
                        print("      Для GOST-шлюза:")
                        print("      - Убедитесь, что используете правильные credentials для auth.bankingapi.ru")
                        print("      - Проверьте, что client_id и client_secret зарегистрированы в реестре API")
                        print("      - Для команды team225 возможно нужны специальные credentials для GOST")
                        print("      - Проверьте реестр: https://api-registry-frontend.bankingapi.ru/")
                    } else {
                        print("      - Проверьте правильность client_id и client_secret")
                        print("      - Убедитесь, что credentials соответствуют документации")
                        print("      - Для endpoint /auth/bank-token используйте client_id=team225 (без суффикса)")
                        print("      - team225-1 может использоваться для других операций, но не для получения токена")
                    }
                }

                throw OAuthError.tokenExchangeFailed(httpResponse.statusCode)
            }

            print("✅ Успешно получен токен")

            if let responseString = String(data: data, encoding: .utf8) {
                print("   Raw response: \(responseString.prefix(200))...")
            }

            let decoder = JSONDecoder()

            let tokenResponse: OAuthTokenResponse
            do {
                tokenResponse = try decoder.decode(OAuthTokenResponse.self, from: data)
            } catch {

                print("❌ Ошибка декодирования ответа:")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Полный ответ: \(responseString)")
                }
                throw error
            }

            print("📋 Информация о токене:")
            print("   Token Type: \(tokenResponse.tokenType)")
            if let expiresIn = tokenResponse.expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                print("   Expires In: \(expiresIn) секунд (\(expiresIn / 3600) часов)")
                print("   Expiration Date: \(expirationDate)")
            }
            if let scope = tokenResponse.scope {
                print("   Scope: \(scope)")
            }

            let tokenPreview = tokenResponse.accessToken.prefix(20) + "..." + tokenResponse.accessToken.suffix(20)
            print("   Access Token: \(tokenPreview)")

            if let jwtInfo = decodeJWT(tokenResponse.accessToken) {
                print("   JWT Info: \(jwtInfo)")
            }

            try tokenManager.saveTokens(tokenResponse, forBank: bankId)

            return tokenResponse
        } catch let error as DecodingError {
            print("❌ Ошибка декодирования ответа: \(error)")

            switch error {
            case .typeMismatch(let type, let context):
                print("   Тип: \(type), Путь: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("   Значение не найдено: \(type), Путь: \(context.codingPath)")
            case .keyNotFound(let key, let context):
                print("   Ключ не найден: \(key.stringValue), Путь: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("   Данные повреждены: \(context.debugDescription)")
            @unknown default:
                print("   Неизвестная ошибка декодирования")
            }
            throw OAuthError.invalidResponse
        } catch {
            print("❌ Ошибка при запросе bank-token: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func authenticate(
        bankId: String,
        configuration: OAuthConfiguration
    ) async -> OAuthResult {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            var authURLComponents = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
            authURLComponents?.queryItems = [
                URLQueryItem(name: "client_id", value: configuration.clientId),
                URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
                URLQueryItem(name: "state", value: generateState()),
                URLQueryItem(name: "code_challenge", value: generateCodeChallenge()),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]

            guard let authURL = authURLComponents?.url else {
                continuation.resume(returning: .failure(OAuthError.invalidURL))
                return
            }

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: configuration.redirectURI)?.scheme,
                completionHandler: { [weak self] callbackURL, error in
                    guard let self = self else { return }

                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(returning: .cancelled)
                        } else {
                            continuation.resume(returning: .failure(error))
                        }
                        return
                    }

                    guard let callbackURL = callbackURL,
                          let code = self.extractCode(from: callbackURL) else {
                        continuation.resume(returning: .failure(OAuthError.invalidCallback))
                        return
                    }

                    Task {
                        let result = await self.exchangeCodeForTokens(
                            code: code,
                            configuration: configuration
                        )
                        continuation.resume(returning: result)
                    }
                }
            )

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            if !session.start() {
                continuation.resume(returning: .failure(OAuthError.sessionStartFailed))
            }

            self.currentSession = session
        }
    }

    func refreshToken(
        bankId: String,
        configuration: OAuthConfiguration
    ) async throws -> OAuthTokenResponse {
        guard let refreshToken = try tokenManager.getRefreshToken(forBank: bankId) else {
            throw OAuthError.noRefreshToken
        }

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI)
        ]

        if let clientSecret = configuration.clientSecret {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "client_secret", value: clientSecret)
            )
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.tokenExchangeFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()

        let tokenResponse = try decoder.decode(OAuthTokenResponse.self, from: data)

        try tokenManager.saveTokens(tokenResponse, forBank: bankId)

        return tokenResponse
    }

    func getValidAccessToken(
        bankId: String,
        configuration: OAuthConfiguration
    ) async throws -> String {
        if tokenManager.needsRefresh(forBank: bankId) {
            _ = try await refreshToken(bankId: bankId, configuration: configuration)
        }

        guard let accessToken = try tokenManager.getAccessToken(forBank: bankId) else {
            throw OAuthError.noAccessToken
        }

        return accessToken
    }

    private func exchangeCodeForTokens(
        code: String,
        configuration: OAuthConfiguration
    ) async -> OAuthResult {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]

        if let clientSecret = configuration.clientSecret {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "client_secret", value: clientSecret)
            )
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(OAuthError.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(OAuthError.tokenExchangeFailed(httpResponse.statusCode))
            }

            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(OAuthTokenResponse.self, from: data)

            return .success(tokenResponse)
        } catch {
            return .failure(error)
        }
    }

    private func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        return queryItems.first(where: { $0.name == "code" })?.value
    }

    private func generateState() -> String {
        return UUID().uuidString
    }

    private func generateCodeChallenge() -> String {

        let codeVerifier = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return codeVerifier
    }

    private func decodeJWT(_ token: String) -> String? {
        let components = token.components(separatedBy: ".")
        guard components.count == 3 else {
            return nil
        }

        guard let payloadData = Data(base64Encoded: components[1], options: .ignoreUnknownCharacters),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }

        var info: [String] = []
        if let sub = payloadJSON["sub"] as? String {
            info.append("sub: \(sub)")
        }
        if let clientId = payloadJSON["client_id"] as? String {
            info.append("client_id: \(clientId)")
        }
        if let type = payloadJSON["type"] as? String {
            info.append("type: \(type)")
        }
        if let iss = payloadJSON["iss"] as? String {
            info.append("iss: \(iss)")
        }
        if let aud = payloadJSON["aud"] as? String {
            info.append("aud: \(aud)")
        }
        if let exp = payloadJSON["exp"] as? Int {
            let expDate = Date(timeIntervalSince1970: TimeInterval(exp))
            info.append("exp: \(exp) (\(expDate))")
        }

        return info.isEmpty ? nil : info.joined(separator: ", ")
    }
}

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }

        #if swift(>=5.9)
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: windowScene)
            }
        }
        #endif

        return UIWindow()
    }
}

enum OAuthError: LocalizedError {
    case invalidURL
    case invalidCallback
    case invalidResponse
    case tokenExchangeFailed(Int)
    case sessionStartFailed
    case noRefreshToken
    case noAccessToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL авторизации"
        case .invalidCallback:
            return "Некорректный ответ от сервера авторизации"
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .tokenExchangeFailed(let statusCode):
            if statusCode == 401 {
                return "Ошибка авторизации (401). Проверьте правильность client_id и client_secret. Убедитесь, что client_id соответствует формату команды (например, team225 без суффикса)."
            } else if statusCode == 404 {
                return "Endpoint не найден (404). Проверьте правильность URL банка."
            } else {
                return "Ошибка обмена кода на токен. Код статуса: \(statusCode)"
            }
        case .sessionStartFailed:
            return "Не удалось запустить сессию авторизации"
        case .noRefreshToken:
            return "Refresh token не найден"
        case .noAccessToken:
            return "Access token не найден"
        }
    }
}
