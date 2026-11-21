//
//  CloudSyncSettingsRegistration.swift
//  PVSettings
//

import Defaults

/// Registers the cloud sync settings' default values from the main thread.
///
/// A `Defaults.Key` registers its default the first time it is read, inside the
/// key's one-time initializer, and `UserDefaults` posts its change notification
/// on the reading thread. SwiftUI answers that notification by taking its update
/// lock. When the first reader is a sync task, a background thread ends up
/// waiting on that lock while it holds the key's initializer, which is where one
/// thread of a background watchdog kill (0x8BADF00D, PROVENANCE-299) was found.
/// Reading the keys once at launch keeps the registration on the main thread.
public enum CloudSyncSettingsRegistration {
    /// Every setting the sync code reads off the main thread.
    static var keys: [Defaults.Keys] {
        [
            Defaults.Keys.iCloudSync,
            Defaults.Keys.iCloudSyncMode,
            Defaults.Keys.cloudKitSyncContentType,
            Defaults.Keys.cloudKitSyncNetworkMode,
            Defaults.Keys.cloudKitSyncFrequency,
            Defaults.Keys.cloudKitSyncOnlyWhenCharging,
            Defaults.Keys.cloudKitRespectLowPowerMode,
            Defaults.Keys.cloudKitMaxCellularFileSize,
            Defaults.Keys.cloudKitBackgroundSync,
            Defaults.Keys.cloudKitAutoResolveConflicts,
            Defaults.Keys.cloudKitShowSyncNotifications,
            Defaults.Keys.cloudKitCompressFiles,
            Defaults.Keys.cloudKitDeleteLocalAfterUpload,
            Defaults.Keys.cloudKitMaxConcurrentUploads,
            Defaults.Keys.cloudKitRetryFailedUploads,
            Defaults.Keys.cloudKitMaxRetryAttempts
        ]
    }

    /// The names of the registered settings.
    static var keyNames: [String] { keys.map(\.name) }

    /// Call once at launch, before anything starts a sync.
    @MainActor
    public static func registerDefaults() {
        _ = keys
    }
}
