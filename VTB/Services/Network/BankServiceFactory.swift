
import Foundation

final class BankServiceFactory {
    static let shared = BankServiceFactory()

    private init() {}

    func createService(
        for bankInfo: BankInfo,
        requestingBankId: String? = nil,
        consentId: String? = nil,
        clientId: String? = nil
    ) -> BankAPIService {
        if bankInfo.supportsGOST {
            return GOSTGatewayServiceImpl(bankInfo: bankInfo)
        } else {

            return StandardOpenBankingService(
                bankInfo: bankInfo,
                requestingBankId: requestingBankId,
                consentId: consentId,
                clientId: clientId
            )
        }
    }

    func createGOSTService(for bankInfo: BankInfo) -> GOSTGatewayService {
        return GOSTGatewayServiceImpl(bankInfo: bankInfo)
    }
}
