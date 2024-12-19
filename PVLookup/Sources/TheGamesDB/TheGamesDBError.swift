import Foundation

/// Errors that can occur when using TheGamesDB
public enum TheGamesDBError: LocalizedError, Equatable {
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

    public static func == (lhs: TheGamesDBError, rhs: TheGamesDBError) -> Bool {
        switch (lhs, rhs) {
        case (.databaseNotInitialized, .databaseNotInitialized),
             (.invalidGameID, .invalidGameID),
             (.gameNotFound, .gameNotFound),
             (.invalidPlatformID, .invalidPlatformID),
             (.invalidImageData, .invalidImageData),
             (.invalidURL, .invalidURL):
            return true
        case (.queryError(let lhsError), .queryError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.databaseError(let lhsError), .databaseError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
