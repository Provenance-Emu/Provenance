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
        
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitSyncer(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud Documents syncer based on iCloudSyncMode=\(syncMode.description)")
            return iCloudContainerSyncer(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
    }
    
    /// Create a ROM sync provider
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    /// - Returns: A ROM sync provider
    public static func createROMSyncProvider(
        notificationCenter: NotificationCenter = .default,
        errorHandler: CloudSyncErrorHandler
    ) -> RomsSyncing {
        // Get the current iCloud sync mode and check if sync is enabled
        let syncMode = Defaults[.iCloudSyncMode]
        let iCloudSyncEnabled = Defaults[.iCloudSync]
        
        // Log the current sync state
        DLOG("iCloudSync=\(iCloudSyncEnabled), iCloudSyncMode=\(syncMode.description)")
        
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit ROM syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitRomsSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud ROM syncer based on iCloudSyncMode=\(syncMode.description)")
            return RomsSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
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
        
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit save states syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitSaveStatesSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud save states syncer based on iCloudSyncMode=\(syncMode.description)")
            return SaveStatesSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
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
        
        // Return the appropriate syncer based on the mode
        if syncMode.isCloudKit {
            DLOG("Creating CloudKit BIOS syncer based on iCloudSyncMode=\(syncMode.description)")
            return CloudKitBIOSSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        } else {
            DLOG("Creating iCloud BIOS syncer based on iCloudSyncMode=\(syncMode.description)")
            return BIOSSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        }
    }
}
