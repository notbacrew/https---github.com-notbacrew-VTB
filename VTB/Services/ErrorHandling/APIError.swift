
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimitExceeded
    case serverError(statusCode: Int)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL запроса"
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP ошибка: \(statusCode)"
        case .decodingError(let error):
            return "Ошибка декодирования данных: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Ошибка кодирования данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .unauthorized:
            return "Требуется авторизация"
        case .forbidden:
            return "Доступ запрещен"
        case .notFound:
            return "Ресурс не найден"
        case .rateLimitExceeded:
            return "Превышен лимит запросов. Попробуйте позже"
        case .serverError(let statusCode):
            return "Ошибка сервера: \(statusCode)"
        case .timeout:
            return "Превышено время ожидания"
        case .cancelled:
            return "Запрос отменен"
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .unauthorized:
            return "Сеанс авторизации истек. Необходимо переподключить банк"
        case .rateLimitExceeded:
            return "Слишком много запросов. Подождите немного и попробуйте снова"
        case .networkError:
            return "Проблемы с интернет-соединением. Проверьте подключение"
        case .timeout:
            return "Сервер не отвечает. Попробуйте позже"
        case .serverError:
            return "Временные проблемы на стороне банка. Попробуйте позже"
        default:
            return errorDescription ?? "Произошла ошибка"
        }
    }

    var shouldRetry: Bool {
        switch self {
        case .networkError, .timeout, .serverError:
            return true
        case .rateLimitExceeded:
            return true
        default:
            return false
        }
    }
}
