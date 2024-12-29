import Foundation
import PVLogging
import PVSQLiteDatabase

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
            DLOG("ShiraGameManager: Database already prepared")
            return
        }

        DLOG("ShiraGameManager: Starting database preparation...")

        let fileManager = FileManager.default
        DLOG("ShiraGameManager: Checking if database needs preparation...")

        // Check if database already exists
        if fileManager.fileExists(atPath: databasePath.path) {
            DLOG("ShiraGameManager: Database already exists")
            return
        }

        DLOG("ShiraGameManager: Database not found, starting extraction...")

        // Get the compressed database from the bundle
        guard let compressedURL = Bundle.module.url(forResource: "shiragame.sqlite3", withExtension: "zip") else {
            DLOG("ShiraGameManager: Failed to find compressed database in bundle")
            throw ShiraGameError.databaseNotFound
        }

        DLOG("ShiraGameManager: Found compressed database at: \(compressedURL)")

        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        DLOG("ShiraGameManager: Created temp directory at: \(tempDir)")

        defer {
            try? fileManager.removeItem(at: tempDir)
            DLOG("ShiraGameManager: Cleaned up temp directory")
        }

        // Extract using Archive
        DLOG("ShiraGameManager: Starting extraction...")
        try extractZipDatabase(from: compressedURL, to: tempDir)
        DLOG("ShiraGameManager: Extraction complete")

        // Move extracted database to final location
        let extractedDB = tempDir.appendingPathComponent("shiragame.sqlite3")
        try fileManager.moveItem(at: extractedDB, to: databasePath)
        DLOG("ShiraGameManager: Moved database to final location")

        isDatabasePrepared = true
        DLOG("ShiraGameManager: Database preparation complete")

        // Verify database exists and is readable
        guard FileManager.default.fileExists(atPath: databasePath.path) else {
            DLOG("ShiraGameManager: Database file not found after preparation!")
            throw ShiraGameError.databaseNotFound
        }

        // Try opening database to verify it's valid
        _ = ShiragameSchema(url: databasePath)
        DLOG("ShiraGameManager: Database verified and ready")
    }

    private func extractZipDatabase(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            #if DEBUG
            print("ShiraGameManager: Using FileManager to unzip database...")
            print("ShiraGameManager: Source file exists: \(FileManager.default.fileExists(atPath: sourceURL.path))")
            print("ShiraGameManager: Source file size: \(try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] ?? 0)")
            #endif

            try FileManager.default.zipItem(at: sourceURL, unzipTo: destinationURL)

            #if DEBUG
            print("ShiraGameManager: Destination directory contents: \(try FileManager.default.contentsOfDirectory(atPath: destinationURL.path))")
            print("ShiraGameManager: Unzip successful")
            #endif
        } catch {
            DLOG("ShiraGameManager: Unzip failed with detailed error: \(error)")
            DLOG("ShiraGameManager: Error domain: \(error as NSError).domain")
            DLOG("ShiraGameManager: Error code: \((error as NSError).code)")
            DLOG("ShiraGameManager: Error description: \((error as NSError).localizedDescription)")
            throw ShiraGameError.extractionFailed
        }
    }
}
