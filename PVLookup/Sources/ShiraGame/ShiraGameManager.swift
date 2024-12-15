import Foundation
import PVLogging

public enum ShiraGameError: Error {
    case databaseNotFound
    case extractionFailed
    case invalidCompressedFile
    case initializationTimeout
}

/// Utility class for managing the ShiraGame database
public actor ShiraGameManager {
    /// Singleton instance to coordinate database operations
    public static let shared = ShiraGameManager()

    /// Path to the extracted database in Caches directory
    public nonisolated var databasePath: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("shiragame.sqlite3")
    }

    private var isDatabasePrepared = false

    /// Ensures the database is extracted and ready to use
    public func prepareDatabaseIfNeeded() async throws {
        if isDatabasePrepared {
            print("ShiraGameManager: Database already prepared")
            return
        }

        print("ShiraGameManager: Starting database preparation...")

        let fileManager = FileManager.default
        print("ShiraGameManager: Checking if database needs preparation...")

        // Check if database already exists
        if fileManager.fileExists(atPath: databasePath.path) {
            print("ShiraGameManager: Database already exists")
            return
        }

        print("ShiraGameManager: Database not found, starting extraction...")

        // Get the compressed database from the bundle
        guard let compressedURL = Bundle.module.url(forResource: "shiragame.sqlite3", withExtension: "zip") else {
            print("ShiraGameManager: Failed to find compressed database in bundle")
            throw ShiraGameError.databaseNotFound
        }

        print("ShiraGameManager: Found compressed database at: \(compressedURL)")

        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("ShiraGameManager: Created temp directory at: \(tempDir)")

        defer {
            try? fileManager.removeItem(at: tempDir)
            print("ShiraGameManager: Cleaned up temp directory")
        }

        // Extract using Archive
        print("ShiraGameManager: Starting extraction...")
        try extractZipDatabase(from: compressedURL, to: tempDir)
        print("ShiraGameManager: Extraction complete")

        // Move extracted database to final location
        let extractedDB = tempDir.appendingPathComponent("shiragame.sqlite3")
        try fileManager.moveItem(at: extractedDB, to: databasePath)
        print("ShiraGameManager: Moved database to final location")

        isDatabasePrepared = true
        print("ShiraGameManager: Database preparation complete")

        // Verify database exists and is readable
        guard FileManager.default.fileExists(atPath: databasePath.path) else {
            print("ShiraGameManager: Database file not found after preparation!")
            throw ShiraGameError.databaseNotFound
        }

        // Try opening database to verify it's valid
        _ = try ShiragameSchema(url: databasePath)
        print("ShiraGameManager: Database verified and ready")
    }

    private func extractZipDatabase(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            print("ShiraGameManager: Using FileManager to unzip database...")
            print("ShiraGameManager: Source file exists: \(FileManager.default.fileExists(atPath: sourceURL.path))")
            print("ShiraGameManager: Source file size: \(try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] ?? 0)")

            try FileManager.default.zipItem(at: sourceURL, unzipTo: destinationURL)

            print("ShiraGameManager: Destination directory contents: \(try FileManager.default.contentsOfDirectory(atPath: destinationURL.path))")
            print("ShiraGameManager: Unzip successful")
        } catch {
            print("ShiraGameManager: Unzip failed with detailed error: \(error)")
            print("ShiraGameManager: Error domain: \(error as NSError).domain")
            print("ShiraGameManager: Error code: \((error as NSError).code)")
            print("ShiraGameManager: Error description: \((error as NSError).localizedDescription)")
            throw ShiraGameError.extractionFailed
        }
    }
}
