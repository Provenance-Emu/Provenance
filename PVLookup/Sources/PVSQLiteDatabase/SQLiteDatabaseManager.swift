import Foundation
import PVLogging
import ZIPFoundation

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

    /// Sidecar file recording which bundled archive contents the extracted database came from.
    ///
    /// Staleness used to be decided by comparing the bundle zip's modification date against the
    /// extracted database's. ZIPFoundation stamps extracted files with the archive entry's
    /// (old) date while the bundle zip carries the build/install date, so that comparison was
    /// always true and every launch deleted and re-extracted hundreds of MB, triggering
    /// MetricKit `MXDiskWriteException`s. A content fingerprint is stable across installs.
    public nonisolated var sourceMarkerPath: URL {
        databasePath.appendingPathExtension("source")
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

        // Get the compressed database from the bundle
        guard let compressedURL = bundle.url(forResource: compressedName, withExtension: "zip") else {
            // No archive to (re-)extract from; fall back to an already extracted copy if present.
            if fileManager.fileExists(atPath: databasePath.path) {
                DLOG("SQLiteDatabaseManager: No bundled zip, using existing database")
                isDatabasePrepared = true
                return
            }
            DLOG("SQLiteDatabaseManager: Failed to find compressed database in bundle")
            throw SQLiteDatabaseError.databaseNotFound
        }

        let fingerprint = archiveFingerprint(of: compressedURL)

        // Check if database already exists and is up to date
        if fileManager.fileExists(atPath: databasePath.path) {
            let storedFingerprint = try? String(contentsOf: sourceMarkerPath, encoding: .utf8)

            if let storedFingerprint, storedFingerprint == fingerprint {
                DLOG("SQLiteDatabaseManager: Database already exists and is up to date")
                isDatabasePrepared = true
                return
            }

            if storedFingerprint == nil || fingerprint == nil {
                // Databases extracted by older builds have no marker. Until now they were
                // re-extracted on every launch, so they already match the bundled archive;
                // adopt them instead of rewriting them yet again.
                DLOG("SQLiteDatabaseManager: Adopting existing database without re-extracting")
                writeSourceMarker(fingerprint)
                isDatabasePrepared = true
                return
            }

            DLOG("SQLiteDatabaseManager: Bundled archive contents changed — re-extracting")
            try? fileManager.removeItem(at: databasePath)
        }

        DLOG("SQLiteDatabaseManager: Database not found, starting extraction from: \(compressedURL)")

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

        writeSourceMarker(fingerprint)

        isDatabasePrepared = true
        DLOG("SQLiteDatabaseManager: Database preparation complete")
    }

    /// Content fingerprint (CRC32 + uncompressed size) of the database entry in the bundled zip.
    /// Only reads the archive's central directory, so it is cheap.
    private func archiveFingerprint(of zipURL: URL) -> String? {
        do {
            let archive = try Archive(url: zipURL, accessMode: .read)
            guard let entry = archive[databaseName] else {
                DLOG("SQLiteDatabaseManager: Entry \(databaseName) not found in \(zipURL.lastPathComponent)")
                return nil
            }
            return "\(entry.checksum)-\(entry.uncompressedSize)"
        } catch {
            DLOG("SQLiteDatabaseManager: Failed to read archive fingerprint: \(error)")
            return nil
        }
    }

    private func writeSourceMarker(_ fingerprint: String?) {
        guard let fingerprint else { return }
        do {
            try fingerprint.write(to: sourceMarkerPath, atomically: true, encoding: .utf8)
        } catch {
            DLOG("SQLiteDatabaseManager: Failed to write source marker: \(error)")
        }
    }
}
