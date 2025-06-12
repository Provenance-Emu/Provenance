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
}
