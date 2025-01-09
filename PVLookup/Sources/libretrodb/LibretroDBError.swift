//
//  LibretroDBError.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/15/24.
//

import Foundation

/// Errors that can occur when working with LibretroDB
public enum LibretroDBError: LocalizedError {
    case databaseNotInitialized
    case invalidGameID
    case gameNotFound
    case invalidMetadata
    case invalidPlatformID
    case invalidImageData
    case invalidURL
    case queryError(Error)
    case databaseError(String)

    public var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "LibretroDB database is not initialized"
        case .invalidGameID:
            return "Invalid game ID provided"
        case .gameNotFound:
            return "Game not found in database"
        case .invalidMetadata:
            return "Invalid metadata in database"
        case .invalidPlatformID:
            return "Invalid platform ID"
        case .invalidImageData:
            return "Invalid image data in database"
        case .invalidURL:
            return "Invalid URL for artwork"
        case .queryError(let error):
            return "Database query error: \(error.localizedDescription)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}
