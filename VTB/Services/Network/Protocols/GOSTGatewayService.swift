
import Foundation
import Security

protocol GOSTGatewayService: BankAPIService {

    func getPublicBankInfo() async throws -> PublicBankInfo

    func signRequest(_ request: inout URLRequest) throws

    func validateGOSTCertificate(_ certificate: SecCertificate) -> Bool
}

struct PublicBankInfo: Codable {
    let bankName: String
    let licenseNumber: String?
    let products: [BankProduct]
    let apiVersion: String?
}

struct BankProduct: Codable {
    let id: String
    let name: String
    let type: ProductType
    let description: String?
}

enum ProductType: String, Codable {
    case account = "account"
    case card = "card"
    case credit = "credit"
    case deposit = "deposit"
    case investment = "investment"
}
