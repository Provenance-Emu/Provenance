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
            DLOG("SQLiteDatabaseManager: Database already prepared")
            return
        }

        DLOG("SQLiteDatabaseManager: Starting database preparation...")

        let fileManager = FileManager.default

        // Check if database already exists and is up to date
        if fileManager.fileExists(atPath: databasePath.path) {
            // If the bundle zip is newer than the extracted DB, re-extract to
            // pick up cheat database updates shipped with new app versions.
            var needsReextract = false
            if let zipURL = bundle.url(forResource: compressedName, withExtension: "zip"),
               let zipDate = (try? fileManager.attributesOfItem(atPath: zipURL.path))?[.modificationDate] as? Date,
               let dbDate  = (try? fileManager.attributesOfItem(atPath: databasePath.path))?[.modificationDate] as? Date,
               zipDate > dbDate {
                DLOG("SQLiteDatabaseManager: Bundle zip is newer than extracted DB — re-extracting")
                try? fileManager.removeItem(at: databasePath)
                needsReextract = true
            }
            if !needsReextract {
                DLOG("SQLiteDatabaseManager: Database already exists and is up to date")
                isDatabasePrepared = true
                return
            }
        }

        DLOG("SQLiteDatabaseManager: Database not found, starting extraction...")

        // Get the compressed database from the bundle
        guard let compressedURL = bundle.url(forResource: compressedName, withExtension: "zip") else {
            DLOG("SQLiteDatabaseManager: Failed to find compressed database in bundle")
            throw SQLiteDatabaseError.databaseNotFound
        }

        DLOG("SQLiteDatabaseManager: Found compressed database at: \(compressedURL)")

        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        DLOG("SQLiteDatabaseManager: Created temp directory at: \(tempDir)")

        defer {
            try? fileManager.removeItem(at: tempDir)
            DLOG("SQLiteDatabaseManager: Cleaned up temp directory")
        }

        // Extract using FileManager+Zip
        DLOG("SQLiteDatabaseManager: Starting extraction...")
        try fileManager.zipItem(at: compressedURL, unzipTo: tempDir)
        DLOG("SQLiteDatabaseManager: Extraction complete")

        // Move extracted database to final location
        let extractedDB = tempDir.appendingPathComponent(databaseName)
        try fileManager.moveItem(at: extractedDB, to: databasePath)
        DLOG("SQLiteDatabaseManager: Moved database to final location")

        isDatabasePrepared = true
        DLOG("SQLiteDatabaseManager: Database preparation complete")
    }
}
