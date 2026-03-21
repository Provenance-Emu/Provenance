//
//  CloudSyncError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import CloudKit

public enum CloudSyncError: Error {
    case noUbiquityURL
    case notImplemented
    case invalidData
    case missingDependency
    /// CloudKit container could not be created (missing entitlements, invalid bundle / Info.plist, etc.).
    case cloudKitContainerUnavailable
    case alreadyExists // Record/file already exists where it shouldn't
    case cloudKitError(Error)
    case fileSystemError(Error)
    case zipError(Error)
    case realmError(Error)
    case unknown
    case recordNotFound
    case genericError(String)
    case gameNotFound(String)

    // CloudKit Account Status Errors
    case noAccount // No iCloud account configured
    case accountRestricted // iCloud account is restricted
    case accountStatusUnknown // Could not determine account status
    case accountTemporarilyUnavailable // Account temporarily unavailable

    // New: Space and Download Management Errors
    case insufficientSpace(required: Int64, available: Int64)
    case downloadCancelled
    case downloadQueueFull
    case assetTooLarge(size: Int64, maxSize: Int64)
    case networkUnavailable
 
    case pausedForEmulation
}

extension CloudSyncError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noUbiquityURL:
            return "No iCloud Drive URL available"
        case .notImplemented:
            return "Feature not implemented"
        case .invalidData:
            return "Invalid data"
        case .missingDependency:
            return "Missing required dependency"
        case .cloudKitContainerUnavailable:
            return "CloudKit is not available (check iCloud / CloudKit entitlements and provisioning)"
        case .alreadyExists:
            return "Record already exists"
        case .cloudKitError(let underlyingError):
            if let ckError = underlyingError as? CKError {
                return "CloudKit error: \(ckError.localizedDescription) (code: \(ckError.code.rawValue))"
            }
            return "CloudKit error: \(underlyingError.localizedDescription)"
        case .fileSystemError(let underlyingError):
            return "File system error: \(underlyingError.localizedDescription)"
        case .zipError(let underlyingError):
            return "Zip error: \(underlyingError.localizedDescription)"
        case .realmError(let underlyingError):
            return "Realm error: \(underlyingError.localizedDescription)"
        case .unknown:
            return "Unknown error"
        case .recordNotFound:
            return "Record not found"
        case .genericError(let message):
            return message
        case .gameNotFound(let message):
            return "Game not found: \(message)"
        case .noAccount:
            return "No iCloud account configured"
        case .accountRestricted:
            return "iCloud account is restricted"
        case .accountStatusUnknown:
            return "Could not determine iCloud account status"
        case .accountTemporarilyUnavailable:
            return "iCloud account temporarily unavailable"
        case .insufficientSpace(let required, let available):
            return "Insufficient space: need \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .downloadCancelled:
            return "Download cancelled"
        case .downloadQueueFull:
            return "Download queue is full"
        case .assetTooLarge(let size, let maxSize):
            return "Asset too large: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) > \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file))"
        case .networkUnavailable:
            return "Network unavailable"
        case .pausedForEmulation:
            return "Paused for emulation"
        }
    }
}
