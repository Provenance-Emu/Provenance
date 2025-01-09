//
//  GameImporterError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public enum GameImporterError: Error, Sendable, CustomNSError, LocalizedError {
    case couldNotCalculateMD5
    case romAlreadyExistsInDatabase
    case noSystemMatched
    case unsupportedSystem
    case systemNotDetermined
    case failedToMoveCDROM(Error)
    case failedToMoveROM(Error)
    case unsupportedFile
    case noBIOSMatchForBIOSFileType
    case unsupportedCDROMFile
    case incorrectDestinationURL
    case conflictDetected
    case missingRequiredProperty(String)
    case systemNotFound

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
        case .failedToMoveCDROM:           return 1006
        case .failedToMoveROM:             return 1007
        case .unsupportedFile:              return 1008
        case .noBIOSMatchForBIOSFileType:   return 1009
        case .unsupportedCDROMFile:         return 1010
        case .incorrectDestinationURL:      return 1011
        case .conflictDetected:             return 1012
        case .missingRequiredProperty:      return 1013
        case .systemNotFound:               return 1014
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
        }
    }
}
