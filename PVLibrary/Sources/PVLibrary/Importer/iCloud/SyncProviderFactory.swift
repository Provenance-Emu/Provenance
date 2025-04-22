//
//  SyncProviderFactory.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

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
        #if os(tvOS)
        return CloudKitSyncer(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        #else
        return iCloudContainerSyncer(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
        #endif
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
        #if os(tvOS)
        DLOG("Creating CloudKit ROM syncer for tvOS")
        let syncer: RomsSyncing = CloudKitRomsSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
        #else
        DLOG("Creating iCloud ROM syncer for iOS/macOS")
        let syncer: RomsSyncing = RomsSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
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
        #if os(tvOS)
        DLOG("Creating CloudKit save states syncer for tvOS")
        let syncer: SaveStatesSyncing = CloudKitSaveStatesSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
        #else
        DLOG("Creating iCloud save states syncer for iOS/macOS")
        let syncer: SaveStatesSyncing = SaveStatesSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
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
        #if os(tvOS)
        DLOG("Creating CloudKit BIOS syncer for tvOS")
        let syncer: BIOSSyncing = CloudKitBIOSSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
        #else
        DLOG("Creating iCloud BIOS syncer for iOS/macOS")
        let syncer: BIOSSyncing = BIOSSyncer(notificationCenter: notificationCenter, errorHandler: errorHandler)
        return syncer
        #endif
    }
}
