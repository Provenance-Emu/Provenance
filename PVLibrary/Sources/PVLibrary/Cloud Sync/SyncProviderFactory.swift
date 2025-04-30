//
//  SyncProviderFactory.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVSettings
import Defaults
import CloudKit

/// Factory for creating sync providers
public class SyncProviderFactory {
    /// Create a sync provider for the specified directories
    /// - Parameters:
    ///   - directories: Directories to sync
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A sync provider
    public static func createSyncProvider(
        for directories: Set<String>,
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> SyncProvider {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        // Log the current sync state
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description)")
        
#if os(tvOS)
        // Get the container identifier from the bundle
        let containerIdentifier = iCloudConstants.containerIdentifier
        let container = CKContainer(identifier: containerIdentifier)
        return CloudKitSyncer(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
#else
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            // Get the container identifier from the bundle
            let containerIdentifier = iCloudConstants.containerIdentifier
            let container = CKContainer(identifier: containerIdentifier)
            DLOG("Creating CloudKit syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitSyncer(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud Documents syncer based on iCloudSyncMode=\(syncMode.description)")
            return iCloudContainerSyncer(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
#endif
    }
    
    /// Create a ROM sync provider
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A ROM sync provider
    public static func createROMSyncProvider(
        container: CKContainer,
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> RomsSyncing {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description), container=\(container)")
#if os(tvOS)
        return CloudKitRomsSyncer(container: container, notificationCenter: notificationCenter, errorHandler: errorHandler)
#else
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit ROM syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitRomsSyncer(container: container, notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud ROM syncer based on iCloudSyncMode=\(syncMode.description)")
            return iCloudDriveRomsSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
#endif
    }
    
    /// Create a save states sync provider
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A save states sync provider
    public static func createSaveStatesSyncProvider(
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> SaveStatesSyncing {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        // Log the current sync state
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description)")
#if os(tvOS)
        return CloudKitSaveStatesSyncer(container: iCloudConstants.container, notificationCenter: notificationCenter, errorHandler: errorHandler)
#else
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit save states syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitSaveStatesSyncer(container: iCloudConstants.container, notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud save states syncer based on iCloudSyncMode=\(syncMode.description)")
            return iCloudDriveSaveStatesSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
#endif
    }
    
    /// Create a BIOS sync provider
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A BIOS sync provider
    public static func createBIOSSyncProvider(
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> BIOSSyncing {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        // Log the current sync state
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description)")
#if os(tvOS)
        return CloudKitBIOSSyncer(container: iCloudConstants.container, notificationCenter: notificationCenter, errorHandler: errorHandler)
#else
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit BIOS syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitBIOSSyncer(container: iCloudConstants.container, notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud BIOS syncer based on iCloudSyncMode=\(syncMode.description)")
            return iCloudDriveBIOSSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
#endif
    }
    
    /// Create a non-database sync provider for files like Battery States, Screenshots, and DeltaSkins
    /// - Parameters:
    ///   - directories: Directories to sync
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A non-database sync provider
    public static func createNonDatabaseSyncProvider(
        container: CKContainer,
        for directories: Set<String>,
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> CloudKitNonDatabaseSyncer {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        // Log the current sync state
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description)")
        
        // For non-database files, we always use CloudKit
        DLOG("Creating CloudKit non-database syncer for directories: \(directories)")
        return CloudKitNonDatabaseSyncer(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
}
