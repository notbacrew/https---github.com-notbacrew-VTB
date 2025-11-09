
import Foundation

final class APIClient {
    private let session: URLSession
    private let maxRetryAttempts: Int
    private let retryDelay: TimeInterval

    init(
        session: URLSession = .shared,
        maxRetryAttempts: Int = Constants.API.maxRetryAttempts,
        retryDelay: TimeInterval = Constants.API.retryDelay
    ) {
        self.session = session
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
    }

    func get<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(
            url: url,
            method: "GET",
            headers: headers,
            body: nil,
            responseType: responseType
        )
    }

    func post<T: Decodable, B: Encodable>(
        url: URL,
        headers: [String: String]? = nil,
        body: B?,
        responseType: T.Type
    ) async throws -> T {
        let bodyData = try body.map { try JSONEncoder().encode($0) }
        return try await performRequest(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData,
            responseType: responseType
        )
    }

    func put<T: Decodable, B: Encodable>(
        url: URL,
        headers: [String: String]? = nil,
        body: B?,
        responseType: T.Type
    ) async throws -> T {
        let bodyData = try body.map { try JSONEncoder().encode($0) }
        return try await performRequest(
            url: url,
            method: "PUT",
            headers: headers,
            body: bodyData,
            responseType: responseType
        )
    }

    func delete<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(
            url: url,
            method: "DELETE",
            headers: headers,
            body: nil,
            responseType: responseType
        )
    }

    func performDataRequest(
        url: URL,
        method: String = "GET",
        headers: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        return try await performRequestWithRetry(
            attempt: 0,
            url: url,
            method: method,
            headers: headers,
            body: body
        )
    }

    private func performRequest<T: Decodable>(
        url: URL,
        method: String,
        headers: [String: String]?,
        body: Data?,
        responseType: T.Type
    ) async throws -> T {
        let (data, _) = try await performRequestWithRetry(
            attempt: 0,
            url: url,
            method: method,
            headers: headers,
            body: body
        )

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performRequestWithRetry(
        attempt: Int,
        url: URL,
        method: String,
        headers: [String: String]?,
        body: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = Constants.API.defaultTimeout

            headers?.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }

            if let body = body {
                request.httpBody = body
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }

            print("🌐 API Request:")
            print("   URL: \(url.absoluteString)")
            print("   Method: \(method)")
            if let headers = headers {
                let safeHeaders = Dictionary(uniqueKeysWithValues: headers.map { key, value in
                    let safeValue = (key.lowercased().contains("authorization") || key.lowercased().contains("secret")) 
                        ? String(value.prefix(20)) + "..." 
                        : value
                    return (key, safeValue)
                })
                print("   Headers: \(safeHeaders)")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            print("📥 API Response:")
            print("   Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.count > 500 ? String(responseString.prefix(500)) + "..." : responseString
                print("   Body: \(preview)")
            }

            let apiError = handleStatusCode(httpResponse.statusCode, data: data)
            if let error = apiError {
                print("❌ API Error: \(error.localizedDescription)")

                if error.shouldRetry && attempt < maxRetryAttempts {
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    print("   Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(
                        attempt: attempt + 1,
                        url: url,
                        method: method,
                        headers: headers,
                        body: body
                    )
                }
                throw error
            }

            return (data, httpResponse)

        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                if attempt < maxRetryAttempts {
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(
                        attempt: attempt + 1,
                        url: url,
                        method: method,
                        headers: headers,
                        body: body
                    )
                }
                throw APIError.timeout
            }
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func handleStatusCode(_ statusCode: Int, data: Data) -> APIError? {
        switch statusCode {
        case 200...299:
            return nil
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode: statusCode)
        default:
            let message = try? JSONDecoder().decode([String: String].self, from: data)["message"]
            return .httpError(statusCode: statusCode, message: message)
        }
    }
}
