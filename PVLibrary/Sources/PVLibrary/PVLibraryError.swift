import Foundation

public enum PVLibraryError: LocalizedError {
    case iCloud(iCloudError)
    case gameImport(GameImporterError)
    case migration(MigrationError)
    case database(DatabaseError)
    case lookup(LookupError)

    public var errorDescription: String? {
        switch self {
        case .iCloud(let error): return error.localizedDescription
        case .gameImport(let error): return error.localizedDescription
        case .migration(let error): return error.localizedDescription
        case .database(let error): return error.localizedDescription
        case .lookup(let error): return error.localizedDescription
        }
    }
}

public enum iCloudError: LocalizedError {
    case noUbiquityURL
    case downloadFailed(Error)
    case syncFailed(Error)
    case fileNotFound(URL)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .noUbiquityURL:
            return "iCloud container URL not available"
        case .downloadFailed(let error):
            return "Failed to download from iCloud: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Failed to sync with iCloud: \(error.localizedDescription)"
        case .fileNotFound(let url):
            return "File not found in iCloud: \(url.path)"
        case .invalidData:
            return "Invalid data in iCloud file"
        }
    }
}

public enum GameImporterError: LocalizedError, Sendable {
    case couldNotCalculateMD5
    case romAlreadyExistsInDatabase
    case noSystemMatched
    case unsupportedSystem
    case failedToMoveCDROM(Error)
    case failedToMoveROM(Error)
    case importFailed(ImportFailure)
    case directoryHandlingFailed(Error)
    case multipleSystemConflict([String])
    case databaseWriteFailed(Error)
    case invalidPath(String)
    case conflictResolutionFailed(String)
    case artworkImportFailed(ArtworkError)
    case lookupFailed(LookupError)

    public enum ImportFailure {
        case singleFile(path: String, error: Error)
        case multipleFiles(failures: [(path: String, error: Error)])
        case batchImportFailed(Error)
        case invalidFileType(path: String)
        case processingFailed(path: String, error: Error)
    }

    public enum ArtworkError {
        case downloadFailed(URL, Error)
        case invalidURL(String)
        case noMatchingGame(String)
        case cacheMiss(String)
        case processingFailed(Error)
    }

    public enum LookupError {
        case emptyMD5Hash
        case invalidSystemID(String)
        case artworkNotFound(String)
        case cacheMiss(String)
        case databaseError(Error)
    }

    public var errorDescription: String? {
        switch self {
        case .couldNotCalculateMD5:
            return "Failed to calculate MD5 hash for ROM"
        case .romAlreadyExistsInDatabase:
            return "ROM already exists in database"
        case .noSystemMatched:
            return "No matching system found for ROM"
        case .unsupportedSystem:
            return "System is not supported"
        case .failedToMoveCDROM(let error):
            return "Failed to move CD-ROM: \(error.localizedDescription)"
        case .failedToMoveROM(let error):
            return "Failed to move ROM: \(error.localizedDescription)"
        case .importFailed(let failure):
            switch failure {
            case .singleFile(let path, let error):
                return "Failed to import file at \(path): \(error.localizedDescription)"
            case .multipleFiles(let failures):
                let paths = failures.map { $0.path }.joined(separator: ", ")
                return "Multiple import failures: \(paths)"
            case .batchImportFailed(let error):
                return "Batch import failed: \(error.localizedDescription)"
            case .invalidFileType(let path):
                return "Invalid file type at path: \(path)"
            case .processingFailed(let path, let error):
                return "Processing failed for file at \(path): \(error.localizedDescription)"
            }
        case .directoryHandlingFailed(let error):
            return "Failed to handle directory: \(error.localizedDescription)"
        case .multipleSystemConflict(let systems):
            return "ROM matches multiple systems: \(systems.joined(separator: ", "))"
        case .databaseWriteFailed(let error):
            return "Failed to write to database: \(error.localizedDescription)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .conflictResolutionFailed(let reason):
            return "Failed to resolve conflict: \(reason)"
        case .artworkImportFailed(let error):
            return "Failed to import artwork: \(error.localizedDescription)"
        case .lookupFailed(let error):
            return "ROM lookup failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

public enum MigrationError: LocalizedError {
    case databaseMigrationFailed(Error)
    case dataMigrationFailed(Error)
    case databaseCorruption(Error)
    case dataCorruption(Error)
}

public enum DatabaseError: LocalizedError {
    case databaseOpenFailed(Error)
    case databaseReadFailed(Error)
    case databaseWriteFailed(Error)
    case databaseCorruption(Error)
}

public enum LookupError: LocalizedError {
    case emptyMD5Hash
    case invalidSystemID(String)
    case artworkNotFound(String)
    case cacheMiss(String)
}
