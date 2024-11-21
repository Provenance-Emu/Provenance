//
//  GameImporterError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public enum GameImporterError: Error, Sendable {
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
    
    func errorString() -> String {
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
        }
    }
}
