//
//  CloudSyncError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public enum CloudSyncError: Error {
    case noUbiquityURL
    case notImplemented
    case invalidData
    case missingDependency
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
}
