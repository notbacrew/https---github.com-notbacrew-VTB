
import Foundation
import CoreData
import Combine

@MainActor
final class BankConnectionViewModel: ObservableObject {
    @Published var availableBanks: [BankInfo] = []
    @Published var connectedBanks: [ConnectedBank] = []
    @Published var isConnecting = false
    @Published var connectingBankId: String?
    @Published var errorMessage: String?
    @Published var showingBankSelection = false

    private let context: NSManagedObjectContext
    private let oauthService = OAuthService.shared
    private let accountAggregator = AccountAggregator.shared
    private let subscriptionService = SubscriptionService.shared

    init(context: NSManagedObjectContext) {
        self.context = context
        loadAvailableBanks()
        loadConnectedBanks()
    }

    func loadAvailableBanks() {

        let keychainManager = KeychainManager.shared

        let vbankClientId = UserDefaults.standard.string(forKey: "vbank_client_id") ?? "team225"
        let vbankClientSecret = (try? keychainManager.getToken(forKey: Constants.KeychainKeys.clientSecret(forBank: "vbank"))) ?? "TzTX9uabeV9P3A8D8h55K2A2Bdl7eoKy"

        let defaultClientId = UserDefaults.standard.string(forKey: "bank_client_id") ?? "team225"
        let defaultClientSecret = (try? keychainManager.getToken(forKey: Constants.KeychainKeys.clientSecret(forBank: "default"))) ?? "TzTX9uabeV9P3A8D8h55K2A2Bdl7eoKy"

        let gostClientId = UserDefaults.standard.string(forKey: "gost_client_id") ?? defaultClientId
        let gostClientSecret = (try? keychainManager.getToken(forKey: Constants.KeychainKeys.clientSecret(forBank: "gost"))) ?? defaultClientSecret

        availableBanks = [
            BankInfo(
                id: "vbank",
                name: "VBank",
                baseURL: URL(string: "https://vbank.open.bankingapi.ru")!,
                oauthConfiguration: OAuthConfiguration(
                    authorizationEndpoint: URL(string: "https://vbank.open.bankingapi.ru/oauth/authorize")!,
                    tokenEndpoint: URL(string: "https://vbank.open.bankingapi.ru/oauth/token")!,
                    clientId: vbankClientId,
                    clientSecret: vbankClientSecret,
                    scopes: OAuthConfiguration.defaultScopes,
                    redirectURI: Constants.OAuth.redirectURI
                ),
                supportsGOST: false
            ),
            BankInfo(
                id: "sbank",
                name: "SBank",
                baseURL: URL(string: "https://sbank.open.bankingapi.ru")!,
                oauthConfiguration: OAuthConfiguration(
                    authorizationEndpoint: URL(string: "https://sbank.open.bankingapi.ru/oauth/authorize")!,
                    tokenEndpoint: URL(string: "https://sbank.open.bankingapi.ru/oauth/token")!,
                    clientId: defaultClientId,
                    clientSecret: defaultClientSecret,
                    scopes: OAuthConfiguration.defaultScopes,
                    redirectURI: Constants.OAuth.redirectURI
                ),
                supportsGOST: false
            ),
            BankInfo(
                id: "abank",
                name: "ABank",
                baseURL: URL(string: "https://abank.open.bankingapi.ru")!,
                oauthConfiguration: OAuthConfiguration(
                    authorizationEndpoint: URL(string: "https://abank.open.bankingapi.ru/oauth/authorize")!,
                    tokenEndpoint: URL(string: "https://abank.open.bankingapi.ru/oauth/token")!,
                    clientId: defaultClientId,
                    clientSecret: defaultClientSecret,
                    scopes: OAuthConfiguration.defaultScopes,
                    redirectURI: Constants.OAuth.redirectURI
                ),
                supportsGOST: false
            ),

            BankInfo(
                id: "gost-bank",
                name: "Банк через GOST-шлюз",
                baseURL: URL(string: "https://api.gost.bankingapi.ru:8443")!,
                oauthConfiguration: OAuthConfiguration(

                    authorizationEndpoint: URL(string: "https://auth.bankingapi.ru/auth/realms/kubernetes/protocol/openid-connect/auth")!,
                    tokenEndpoint: URL(string: "https://auth.bankingapi.ru/auth/realms/kubernetes/protocol/openid-connect/token")!,
                    clientId: gostClientId,
                    clientSecret: gostClientSecret,
                    scopes: OAuthConfiguration.defaultScopes,
                    redirectURI: Constants.OAuth.redirectURI
                ),
                supportsGOST: true
            )
        ]
    }

    func loadConnectedBanks() {
        let request: NSFetchRequest<ConnectedBank> = ConnectedBank.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConnectedBank.connectedDate, ascending: false)]

        connectedBanks = (try? context.fetch(request)) ?? []
    }

    func connectBank(_ bankInfo: BankInfo) async {
        isConnecting = true
        connectingBankId = bankInfo.id
        errorMessage = nil

        do {

            let request: NSFetchRequest<ConnectedBank> = ConnectedBank.fetchRequest()
            request.predicate = NSPredicate(format: "bankId == %@", bankInfo.id)

            if let existingBank = try? context.fetch(request).first {
                if existingBank.isActive {
                    errorMessage = "Банк \(bankInfo.name) уже подключен"
                    isConnecting = false
                    connectingBankId = nil
                    return
                } else {
                    context.delete(existingBank)
                    do {
                        try context.save()
                    } catch {
                        print("⚠️ Ошибка при удалении старой записи банка: \(error)")
                    }
                }
            }

            if !subscriptionService.canUseFeature(.unlimitedBanks, context: context) {
                errorMessage = "Достигнут лимит подключенных банков (\(subscriptionService.currentTier.maxBankConnections)). Для подключения большего количества банков требуется Premium подписка."
                isConnecting = false
                connectingBankId = nil
                return
            }

            guard let clientSecret = bankInfo.oauthConfiguration.clientSecret else {
                errorMessage = "Не указан client_secret"
                isConnecting = false
                connectingBankId = nil
                return
            }

            do {
                let tokenResponse = try await oauthService.getBankToken(
                    bankId: bankInfo.id,
                    clientId: bankInfo.oauthConfiguration.clientId,
                    clientSecret: clientSecret,
                    baseURL: bankInfo.baseURL,
                    isGOST: bankInfo.supportsGOST
                )

                try? KeychainManager.shared.saveToken(
                    clientSecret,
                    forKey: Constants.KeychainKeys.clientSecret(forBank: bankInfo.id)
                )

                let connectedBank = ConnectedBank.create(
                    from: bankInfo,
                    context: context
                )

                connectedBank.requestingBankId = "team225"

                let consentService = ConsentService.shared
                do {
                    let consentResponse = try await consentService.createAccountConsent(
                        bankToken: tokenResponse.accessToken,
                        clientId: bankInfo.oauthConfiguration.clientId,
                        requestingBank: "team225",
                        baseURL: bankInfo.baseURL
                    )

                    connectedBank.consentId = consentResponse.consentId
                    print("Согласие создано: \(consentResponse.consentId), статус: \(consentResponse.status.rawValue)")
                } catch {

                    print("Ошибка создания согласия: \(error)")
                }

                try context.save()

                do {
                    _ = try await accountAggregator.syncAccounts(
                        for: connectedBank,
                        context: context
                    )
                } catch {

                    print("Ошибка синхронизации счетов: \(error)")
                }

                loadConnectedBanks()

                print("✅ Банк \(bankInfo.name) успешно подключен")
            } catch let error as OAuthError {

                if bankInfo.supportsGOST {
                    if case .tokenExchangeFailed(let statusCode) = error, statusCode == 400 || statusCode == 401 {
                        errorMessage = """
                        Не удалось подключиться к GOST-шлюзу.
                        Для работы с GOST-шлюзом требуются специальные credentials, зарегистрированные в реестре API.
                        Что нужно сделать:
                        1. Зайдите в реестр: https://api-registry-frontend.bankingapi.ru/
                        2. Зарегистрируйте приложение для GOST-шлюза
                        3. Получите client_id и client_secret для auth.bankingapi.ru
                        4. Настройте их в приложении через настройки
                        Текущие credentials (team225) работают только для обычных банков (VBank, SBank, ABank).
                        """
                    } else {
                        errorMessage = "Ошибка подключения к GOST-шлюзу: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Ошибка подключения к банку: \(error.localizedDescription)"
                }
                isConnecting = false
                connectingBankId = nil
                return
            } catch {
                errorMessage = "Ошибка подключения к банку: \(error.localizedDescription)"
                isConnecting = false
                connectingBankId = nil
                return
            }

            isConnecting = false
            connectingBankId = nil
        }
    }

    func disconnectBank(_ bank: ConnectedBank) async {
        do {

            if let bankId = bank.bankId {
                try TokenManager.shared.deleteTokens(forBank: bankId)
            }

            bank.isActive = false

            try context.save()

            loadConnectedBanks()
        } catch {
            errorMessage = "Ошибка отключения: \(error.localizedDescription)"
        }
    }

    func isBankConnected(_ bankId: String) -> Bool {
        return connectedBanks.contains { $0.bankId == bankId }
    }
}
