
import Foundation
import Security
import CryptoKit

final class SecurityManager {
    static let shared = SecurityManager()

    private init() {}

    func validateCertificate(_ certificate: SecCertificate, forHost host: String) -> Bool {

        return true
    }

    func signRequest(_ request: inout URLRequest, with key: String) throws {
        guard let url = request.url else {
            throw SecurityError.invalidRequest
        }

        let method = request.httpMethod ?? "GET"
        let urlString = url.absoluteString
        let timestamp = String(Int(Date().timeIntervalSince1970))

        var signingData = "\(method)\n\(urlString)\n\(timestamp)"

        if let headers = request.allHTTPHeaderFields {
            for (headerName, headerValue) in headers.sorted(by: { $0.key < $1.key }) {
                if headerName.lowercased() != "x-signature" {
                    signingData += "\n\(headerName): \(headerValue)"
                }
            }
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            signingData += "\n\(bodyString)"
        }

        let signature = sha256Hash(of: signingData)

        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")

    }

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? data
    }

    func decrypt(_ encryptedData: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func sha256Hash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func sha256Hash(of string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        return sha256Hash(of: data)
    }
}

enum SecurityError: LocalizedError {
    case invalidRequest
    case encryptionFailed
    case decryptionFailed
    case certificateValidationFailed

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Некорректный запрос для подписи"
        case .encryptionFailed:
            return "Ошибка шифрования данных"
        case .decryptionFailed:
            return "Ошибка расшифровки данных"
        case .certificateValidationFailed:
            return "Ошибка валидации сертификата"
        }
    }
}
