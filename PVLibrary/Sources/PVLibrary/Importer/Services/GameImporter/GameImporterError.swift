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
}
