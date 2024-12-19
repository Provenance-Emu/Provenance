import Foundation

/// Errors that can occur when using TheGamesDB
public enum TheGamesDBError: LocalizedError {
    case databaseNotInitialized
    case invalidGameID
    case gameNotFound
    case invalidPlatformID
    case invalidImageData
    case invalidURL
    case queryError(Error)
    case databaseError(Error)

    public var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "TheGamesDB database is not initialized"
        case .invalidGameID:
            return "Invalid game ID provided"
        case .gameNotFound:
            return "Game not found in database"
        case .invalidPlatformID:
            return "Invalid platform ID"
        case .invalidImageData:
            return "Invalid image data in database"
        case .invalidURL:
            return "Invalid URL for artwork"
        case .queryError(let error):
            return "Database query error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
