//
//  Notifications.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import Foundation

public extension Notification.Name {
    // Database Changes
    static let PVGameDidChange = Notification.Name("PVGameDidChangeNotification")
    static let PVGameSystemDidChange = Notification.Name("PVGameSystemDidChangeNotification")
    static let PVSystemDidChange = Notification.Name("PVSystemDidChangeNotification")
    static let PVSaveStateDidChange = Notification.Name("PVSaveStateDidChangeNotification")
    static let PVBIOSDidChange = Notification.Name("PVBIOSDidChangeNotification")
    static let PVConflictDidChange = Notification.Name("PVConflictDidChangeNotification")
    
    // Database Events
    static let DatabaseMigrationStarted = Notification.Name("DatabaseMigrationStarted")
    static let DatabaseMigrationFinished = Notification.Name("DatabaseMigrationFinished")
    static let DatabaseRebuildStarted = Notification.Name("DatabaseRebuildStarted")
    static let DatabaseRebuildFinished = Notification.Name("DatabaseRebuildFinished")
    static let PVGameWillBeDeleted = Notification.Name("PVGameWillBeDeletedNotification") // Added for pre-deletion hook
    
    // Import Events
    static let GameImporterDidStart = Notification.Name("GameImporterDidStart")
    static let GameImporterDidUpdate = Notification.Name("GameImporterDidUpdate")
    static let GameImporterDidFinish = Notification.Name("GameImporterDidFinish")
    static let GameImporterFileDidFail = Notification.Name("GameImporterFileDidFail")
    static let PVGameImported = Notification.Name("PVGameImportedNotification") // Added
    static let saveStatesImported = Notification.Name("SaveStatesImportFinished")
    static let SavesFinishedImporting = Notification.Name("SavesFinishedImporting")
    static let RomDatabaseInitialized = Notification.Name("RomDatabaseInitialized")

    // Download Events (Could be combined with Import?)
    static let romDownloadCompleted = Notification.Name("PVROMDownloadCompletedNotification") // Added

    // Save State Events
    static let PVSaveStateSaved = Notification.Name("PVSaveStateSavedNotification") // Added
    
    // CloudKit Sync Events
    static let cloudKitAccountStateDidChange = Notification.Name("CloudKitAccountStateDidChange")
    static let cloudKitSyncDidBegin = Notification.Name("CloudKitSyncDidBegin")
    static let cloudKitSyncProgress = Notification.Name("CloudKitSyncProgress")
    static let cloudKitSyncDidComplete = Notification.Name("CloudKitSyncDidComplete")
    static let cloudKitSyncError = Notification.Name("CloudKitSyncError")
    static let cloudKitZoneChanged = Notification.Name("CloudKitZoneChanged") // Added for zone notifications
}
