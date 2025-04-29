//
//  StatusNotifications.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation

/// Extension to define notification names for various system status updates
public extension Notification.Name {
    // MARK: - File System Operations
    
    /// Notification posted when disk space is running low
    static let diskSpaceWarning = Notification.Name("DiskSpaceWarningNotification")
    
    /// Notification posted when temporary files are being cleaned up
    static let temporaryFileCleanupStarted = Notification.Name("TemporaryFileCleanupStartedNotification")
    
    /// Notification posted when temporary file cleanup is complete
    static let temporaryFileCleanupCompleted = Notification.Name("TemporaryFileCleanupCompletedNotification")
    
    /// Notification posted with progress during temporary file cleanup
    static let temporaryFileCleanupProgress = Notification.Name("TemporaryFileCleanupProgressNotification")
    
    /// Notification posted when cache management operations start
    static let cacheManagementStarted = Notification.Name("CacheManagementStartedNotification")
    
    /// Notification posted when cache management operations complete
    static let cacheManagementCompleted = Notification.Name("CacheManagementCompletedNotification")
    
    /// Notification posted with progress during cache management operations
    static let cacheManagementProgress = Notification.Name("CacheManagementProgressNotification")
    
    // MARK: - Network Operations
    
    /// Notification posted when network connectivity changes
    static let networkConnectivityChanged = Notification.Name("NetworkConnectivityChangedNotification")
    
    /// Notification posted when download queue status changes
    static let downloadQueueChanged = Notification.Name("DownloadQueueChangedNotification")
    
    /// Notification posted with progress during downloads
    static let downloadProgress = Notification.Name("DownloadProgressNotification")
    
    /// Notification posted when web server status changes
    static let webServerStatusChanged = Notification.Name("WebServerStatusChangedNotification")
    
    /// Notification posted with progress during web server uploads
    static let webServerUploadProgress = Notification.Name("WebServerUploadProgressNotification")
    
    // MARK: - Controller Management
    
    /// Notification posted when a controller is connected
    static let controllerConnected = Notification.Name("ControllerConnectedNotification")
    
    /// Notification posted when a controller is disconnected
    static let controllerDisconnected = Notification.Name("ControllerDisconnectedNotification")
    
    /// Notification posted when controller mapping starts
    static let controllerMappingStarted = Notification.Name("ControllerMappingStartedNotification")
    
    /// Notification posted when controller mapping completes
    static let controllerMappingCompleted = Notification.Name("ControllerMappingCompletedNotification")
    
    /// Notification posted when MFi controller configurations change
    static let mfiControllerConfigChanged = Notification.Name("MFiControllerConfigChangedNotification")
    
    // MARK: - ROM Scanning
    
    /// Notification posted when ROM scanning starts
    static let romScanningStarted = Notification.Name("ROMScanningStartedNotification")
    
    /// Notification posted when ROM scanning completes
    static let romScanningCompleted = Notification.Name("ROMScanningCompletedNotification")
    
    /// Notification posted with progress during ROM scanning
    static let romScanningProgress = Notification.Name("ROMScanningProgressNotification")
    
    // MARK: - CloudKit Sync Operations
    
    /// Notification posted when initial CloudKit sync starts
    static let cloudKitInitialSyncStarted = Notification.Name("CloudKitInitialSyncStartedNotification")
    
    /// Notification posted when initial CloudKit sync completes
    static let cloudKitInitialSyncCompleted = Notification.Name("CloudKitInitialSyncCompletedNotification")
    
    /// Notification posted with progress during initial CloudKit sync
    static let cloudKitInitialSyncProgress = Notification.Name("CloudKitInitialSyncProgressNotification")
    
    /// Notification posted when CloudKit zone changes start
    static let cloudKitZoneChangesStarted = Notification.Name("CloudKitZoneChangesStartedNotification")
    
    /// Notification posted when CloudKit zone changes complete
    static let cloudKitZoneChangesCompleted = Notification.Name("CloudKitZoneChangesCompletedNotification")
    
    /// Notification posted when CloudKit record upload/download starts
    static let cloudKitRecordTransferStarted = Notification.Name("CloudKitRecordTransferStartedNotification")
    
    /// Notification posted when CloudKit record upload/download completes
    static let cloudKitRecordTransferCompleted = Notification.Name("CloudKitRecordTransferCompletedNotification")
    
    /// Notification posted with progress during CloudKit record upload/download
    static let cloudKitRecordTransferProgress = Notification.Name("CloudKitRecordTransferProgressNotification")
    
    /// Notification posted when CloudKit sync conflicts are detected
    static let cloudKitConflictsDetected = Notification.Name("CloudKitConflictsDetectedNotification")
    
    /// Notification posted when CloudKit sync conflicts are resolved
    static let cloudKitConflictsResolved = Notification.Name("CloudKitConflictsResolvedNotification")
    
    static let startFullSync = Notification.Name("startFullSync")
    static let resetCloudSync = Notification.Name("resetCloudSync")
    static let iCloudSyncStarted = Notification.Name("CloudKitSyncStarted")
    static let iCloudSyncCompleted = Notification.Name("CloudKitSyncCompleted")
    static let iCloudSyncFailed = Notification.Name("CloudKitSyncFailed")
    static let iCloudFileRecoveryProgress = Notification.Name("iCloudFileRecoveryProgress")
    static let iCloudSyncEnabled = Notification.Name("iCloudSyncEnabled")
    static let iCloudSyncDisabled = Notification.Name("iCloudSyncDisabled")
}
