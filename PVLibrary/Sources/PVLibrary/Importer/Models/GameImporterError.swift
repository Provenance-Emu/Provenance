//
//  GameImporterError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public enum GameImporterError: Error, Sendable, CustomNSError, LocalizedError {
    case archiveIsEmpty
    case artworkImportFailed
    case biosNotFound
    case conflictDetected
    case couldNotCalculateMD5
    case couldNotCreateDestinationPath(path: String)
    case couldNotOpenArchive
    case cueProcessingFailed(reason: String)
    case errorGettingFileAttributes(path: String, error: Error)
    case failedToMoveCDROM(Error)
    case failedToMoveROM(Error)
    case fileMoveFailed(source: String, destination: String, error: Error)
    case incorrectDestinationURL
    case invalidBIOSLocation(path: String)
    case m3uProcessingFailed(reason: String)
    case missingRequiredProperty(String)
    case noBIOSMatchForBIOSFileType
    case noSystemMatched
    case romAlreadyExistsInDatabase
    case systemNotDetermined
    case systemNotFound
    case unsupportedCDROMFile
    case unsupportedFile
    case unsupportedFileExtension(ext: String)
    case unsupportedSystem
    case userCancelledSelection
    case waitingForAssociatedFiles(expected: [String])
    
    /// The domain of the error.
    public static var errorDomain: String {
        return "org.provenance-emu.provenance.GameImporter"
    }

    /// The error code within the given domain.
    public var errorCode: Int {
        switch self {
        case .couldNotCalculateMD5:         return 1001
        case .romAlreadyExistsInDatabase:   return 1002
        case .noSystemMatched:              return 1003
        case .unsupportedSystem:            return 1004
        case .systemNotDetermined:          return 1005
        case .failedToMoveCDROM:            return 1006
        case .failedToMoveROM:              return 1007
        case .unsupportedFile:              return 1008
        case .noBIOSMatchForBIOSFileType:   return 1009
        case .unsupportedCDROMFile:         return 1010
        case .incorrectDestinationURL:      return 1011
        case .conflictDetected:             return 1012
        case .missingRequiredProperty:      return 1013
        case .systemNotFound:               return 1014
        case .artworkImportFailed:          return 1015
        case .archiveIsEmpty:               return 1016
        case .biosNotFound:                     return 1017
        case .couldNotCreateDestinationPath(_): return 1018
        case .couldNotOpenArchive:              return 1019
        default:                            return 9999
        }
    }

    /// LocalizedError conformance
    public var errorDescription: String? {
        switch self {
            default: return errorString
        }
    }

    public var failureReason: String? {
        switch self {
            default: return errorString
        }
    }

    /// The user-info dictionary.
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        if let description = errorDescription {
            userInfo[NSLocalizedDescriptionKey] = description
        }
        if let reason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }
        return userInfo
    }

    var errorString: String {
        switch self {
        case .couldNotCalculateMD5:
            return "Fail to get MD5"
        case .romAlreadyExistsInDatabase:
            return "Duplicate ROM"
        case .noSystemMatched:
            return "No System Match"
        case .unsupportedSystem:
            return "Unsupported System"
        case .systemNotDetermined:
            return "Failed to determine system"
        case .failedToMoveCDROM(let error):
            return "Failed to move CDROM files: \(error.localizedDescription)"
        case .failedToMoveROM(let error):
            return "Failed to move ROM files: \(error.localizedDescription)"
        case .unsupportedFile:
            return "Unsupported File type"
        case .noBIOSMatchForBIOSFileType:
            return "Failed to find BIOS System Match"
        case .unsupportedCDROMFile:
            return "Unsupported CDROM File"
        case .incorrectDestinationURL:
            return "Internal Error - Bad Destination Path"
        case .conflictDetected:
            return "Conflict"
        case .missingRequiredProperty(let property):
            return "Missing required property: \(property)"
        case .systemNotFound:
            return "System not found in database"
        case .artworkImportFailed:
            return "Artwork import failed"
        case .unsupportedFileExtension(let ext):
            return "Unsupported file extension: \(ext)"
        case .couldNotOpenArchive:
            return "Could not open archive"
        case .archiveIsEmpty:
            return "Archive is empty"
        case .couldNotCreateDestinationPath(let path):
            return "Could not create destination path: \(path)"
        case .fileMoveFailed(let source, let destination, let error):
            return "Failed to move file from \(source) to \(destination): \(error.localizedDescription)"
        case .errorGettingFileAttributes(let path, let error):
            return "Error getting file attributes for \(path): \(error.localizedDescription)"
        case .noSystemMatched:
            return "No system matched for this file"
        case .biosNotFound:
            return "BIOS file not found"
        case .romAlreadyExistsInDatabase:
            return "ROM file already exists in database"
        case .artworkImportFailed:
            return "Artwork import failed"
        case .userCancelledSelection:
            return "User cancelled selection"
        case .incorrectDestinationURL:
            return "Incorrect destination URL"
        case .couldNotCalculateMD5:
            return "Could not calculate MD5"
        case .m3uProcessingFailed(let reason):
            return "M3U processing failed: \(reason)"
        case .cueProcessingFailed(let reason):
            return "CUE processing failed: \(reason)"
        case .invalidBIOSLocation(let path):
            return "BIOS file found at invalid location: \(path). BIOS files should be in the BIOS folder or a subfolder."
        case .waitingForAssociatedFiles(let expected):
            return "Import item is waiting for associated files: \(expected.joined(separator: ", "))"
        }
    }
}
