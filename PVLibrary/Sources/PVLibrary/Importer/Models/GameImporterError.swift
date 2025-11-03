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
            return "Unable to verify file integrity. The file may be corrupted or inaccessible."
        case .romAlreadyExistsInDatabase:
            return "This game is already in your library. To import it again, remove the existing copy first."
        case .noSystemMatched:
            return "Could not identify which system this game belongs to. Try renaming the file to include the system name (e.g., \"Game Name (NES).zip\")."
        case .unsupportedSystem:
            return "This system is not supported. Check that the required core is installed."
        case .systemNotDetermined:
            return "Could not determine the game system. Make sure the file extension matches a supported system."
        case .failedToMoveCDROM(let error):
            return "Failed to import CD-ROM files: \(error.localizedDescription). Check that you have enough storage space."
        case .failedToMoveROM(let error):
            return "Failed to import game: \(error.localizedDescription). Check that you have enough storage space and file permissions."
        case .unsupportedFile:
            return "This file type is not supported. Supported formats include ZIP archives and ROM files for supported systems."
        case .noBIOSMatchForBIOSFileType:
            return "Could not match this BIOS file to a system. Place BIOS files in the BIOS folder with their correct names."
        case .unsupportedCDROMFile:
            return "This CD-ROM format is not supported. Make sure you have all required files (CUE and BIN files together)."
        case .incorrectDestinationURL:
            return "Internal error: Invalid destination path. Please try importing again."
        case .conflictDetected:
            return "Multiple systems match this file. Please select which system to use in the import queue."
        case .missingRequiredProperty(let property):
            return "Missing required information: \(property). The file may be incomplete or corrupted."
        case .systemNotFound:
            return "The system for this game was not found. Make sure the required core is installed."
        case .artworkImportFailed:
            return "Failed to import artwork. The image file may be corrupted or in an unsupported format."
        case .unsupportedFileExtension(let ext):
            return "File extension \".\(ext)\" is not supported. Check the file format and try again."
        case .couldNotOpenArchive:
            return "Could not open archive file. The ZIP file may be corrupted or password-protected."
        case .archiveIsEmpty:
            return "The archive file is empty. Make sure the ZIP file contains game files."
        case .couldNotCreateDestinationPath(let path):
            return "Could not create destination folder: \(path). Check storage permissions and available space."
        case .fileMoveFailed(let source, let destination, let error):
            return "Failed to move file: \(error.localizedDescription). Check storage space and permissions."
        case .errorGettingFileAttributes(let path, let error):
            return "Could not read file information: \(error.localizedDescription). The file may be inaccessible."
        case .biosNotFound:
            return "Required BIOS file not found. Place BIOS files in the BIOS folder. Check the wiki for required BIOS files."
        case .userCancelledSelection:
            return "Import cancelled"
        case .m3uProcessingFailed(let reason):
            return "Failed to process playlist file: \(reason). Make sure all referenced files are present."
        case .cueProcessingFailed(let reason):
            return "Failed to process CUE sheet: \(reason). Make sure the CUE file and all referenced BIN files are in the same folder."
        case .invalidBIOSLocation(let path):
            return "BIOS file found at invalid location: \(path). BIOS files should be placed in the BIOS folder or a system-specific subfolder."
        case .waitingForAssociatedFiles(let expected):
            return "Waiting for required files: \(expected.joined(separator: ", ")). Make sure all files are imported together."
        }
    }
}
