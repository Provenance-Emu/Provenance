import Foundation
import PVLogging

public enum ShiraGameError: Error {
    case databaseNotFound
    case extractionFailed
    case invalidCompressedFile
}

/// Utility class for managing the ShiraGame database
public enum ShiraGameManager {
    /// Path to the extracted database in Caches directory
    public static var databasePath: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("shiragame.sqlite3")
    }

    /// Ensures the database is extracted and ready to use
    public static func prepareDatabaseIfNeeded() throws {
        let fileManager = FileManager.default

        // Check if database already exists
        if fileManager.fileExists(atPath: databasePath.path) {
            return
        }

        // Get the compressed database from the bundle
        guard let compressedURL = Bundle.module.url(forResource: "shiragame.sqlite3", withExtension: "7z") else {
            throw ShiraGameError.databaseNotFound
        }

        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract using Archive
        try extractZipDatabase(from: compressedURL, to: tempDir)

        // Move extracted database to final location
        let extractedDB = tempDir.appendingPathComponent("shiragame.sqlite3")
        try fileManager.moveItem(at: extractedDB, to: databasePath)
    }

    private static func extractZipDatabase(from sourceURL: URL, to destinationURL: URL) throws {
        guard (try? FileManager.default.zipItem(at: sourceURL, unzipTo: destinationURL)) != nil else {
            throw ShiraGameError.extractionFailed
        }
    }
}
