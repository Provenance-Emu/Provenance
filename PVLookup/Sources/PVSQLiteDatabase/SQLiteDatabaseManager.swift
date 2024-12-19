import Foundation
import PVLogging

public enum SQLiteDatabaseError: Error {
    case databaseNotFound
    case extractionFailed
    case invalidCompressedFile
    case initializationTimeout
}

/// Manages SQLite database initialization and extraction
public actor SQLiteDatabaseManager {
    /// Path to the extracted database in Caches directory
    public nonisolated var databasePath: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(databaseName)
    }

    private let bundle: Bundle
    private let databaseName: String
    private let compressedName: String
    private var isDatabasePrepared = false

    public init(bundle: Bundle, databaseName: String, compressedName: String? = nil) {
        self.bundle = bundle
        self.databaseName = databaseName
        self.compressedName = compressedName ?? databaseName
    }

    /// Ensures the database is extracted and ready to use
    public func prepareDatabaseIfNeeded() async throws {
        if isDatabasePrepared {
            print("SQLiteDatabaseManager: Database already prepared")
            return
        }

        print("SQLiteDatabaseManager: Starting database preparation...")

        let fileManager = FileManager.default

        // Check if database already exists
        if fileManager.fileExists(atPath: databasePath.path) {
            print("SQLiteDatabaseManager: Database already exists")
            isDatabasePrepared = true
            return
        }

        print("SQLiteDatabaseManager: Database not found, starting extraction...")

        // Get the compressed database from the bundle
        guard let compressedURL = bundle.url(forResource: compressedName, withExtension: "zip") else {
            print("SQLiteDatabaseManager: Failed to find compressed database in bundle")
            throw SQLiteDatabaseError.databaseNotFound
        }

        print("SQLiteDatabaseManager: Found compressed database at: \(compressedURL)")

        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("SQLiteDatabaseManager: Created temp directory at: \(tempDir)")

        defer {
            try? fileManager.removeItem(at: tempDir)
            print("SQLiteDatabaseManager: Cleaned up temp directory")
        }

        // Extract using FileManager+Zip
        print("SQLiteDatabaseManager: Starting extraction...")
        try fileManager.zipItem(at: compressedURL, unzipTo: tempDir)
        print("SQLiteDatabaseManager: Extraction complete")

        // Move extracted database to final location
        let extractedDB = tempDir.appendingPathComponent(databaseName)
        try fileManager.moveItem(at: extractedDB, to: databasePath)
        print("SQLiteDatabaseManager: Moved database to final location")

        isDatabasePrepared = true
        print("SQLiteDatabaseManager: Database preparation complete")
    }
}
