import Foundation

/// Errors that can occur when interacting with the RetroAchievements API
public enum RetroError: Error, Sendable {
    /// Network-related errors
    case network(Error)

    /// Network-related errors (alternative naming)
    case networkError(Error)

    /// Invalid response format
    case invalidResponse

    /// Invalid URL
    case invalidURL

    /// Authentication failed
    case unauthorized

    /// Authentication failed (alternative naming)
    case authenticationFailed

    /// Resource not found
    case notFound

    /// Server error with optional message
    case serverError(String?)

    /// Invalid credentials provided
    case invalidCredentials

    /// Rate limit exceeded
    case rateLimitExceeded

    /// Custom error with message
    case custom(String)
}

extension RetroError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .network(let error), .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response format"
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized, .authenticationFailed:
            return "Authentication failed"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return "Server error: \(message ?? "Unknown error")"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .custom(let message):
            return message
        }
    }
}

/// Error response structure from the API
public struct ErrorResponse: Codable, Sendable {
    public let message: String?
    public let code: String?

    enum CodingKeys: String, CodingKey {
        case message = "message"
        case code = "code"
    }
}
