//
//  Notifications.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import Foundation

public extension Notification.Name {
    static let DatabaseMigrationStarted = Notification.Name("DatabaseMigrarionStarted")
    static let DatabaseMigrationFinished = Notification.Name("DatabaseMigrarionFinished")
    static let NewCloudFilesAvailable = Notification.Name("NewCloudFilesAvailable")
    static let RomDatabaseInitialized = Notification.Name("RomDatabaseInitialized")
    static let RomsFinishedImporting = Notification.Name("RomsFinishedImporting")
}
