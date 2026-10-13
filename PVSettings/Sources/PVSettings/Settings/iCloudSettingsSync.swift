//
//  iCloudSettingsSync.swift
//  PVSettings
//
//  Bridges key user preferences with NSUbiquitousKeyValueStore so they
//  survive app reinstalls (UserDefaults is deleted on uninstall, iCloud KVS is not).
//

import Foundation
import Defaults

/// Syncs critical user preferences to NSUbiquitousKeyValueStore so they persist
/// across app reinstalls. On first launch after reinstall, restores values from
/// iCloud KVS back into UserDefaults (Defaults library).
public enum iCloudSettingsSync {

    /// What to do with one synced setting at launch.
    enum StartupAction: Equatable {
        /// This device already has its own value (e.g. upgrading from 3.3.x): keep it.
        case keepLocal
        /// Reinstall or new device: nothing local yet, so restore what iCloud has.
        case adoptRemote
        /// iCloud has nothing yet: seed it with this device's value.
        case seedRemote
        /// Nothing chosen anywhere.
        case none
    }

    /// Decides one key at launch. A value stored on this device always wins, and an existing
    /// iCloud value is never overwritten at launch: pushing on every launch let whichever device
    /// launched last flip sync on or off, or between CloudKit and iCloud Drive, on every other
    /// device. Later changes still sync through the observers below.
    static func startupAction(hasLocalValue: Bool, hasRemoteValue: Bool) -> StartupAction {
        switch (hasLocalValue, hasRemoteValue) {
        case (true, true): return .keepLocal
        case (false, true): return .adoptRemote
        case (true, false): return .seedRemote
        case (false, false): return .none
        }
    }

    // MARK: - Public API

    /// Call once at app launch (e.g. in AppDelegate or App.init).
    /// Reconciles each synced setting with iCloud KVS (see `startupAction`), then starts
    /// observing local and remote changes.
    public static func setup() {
        let kvs = NSUbiquitousKeyValueStore.default

        // Pull latest from iCloud
        kvs.synchronize()

        reconcileAtStartup(kvs)

        // Observe external changes from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { notification in
            handleExternalChange(notification)
        }

        // Observe local Defaults changes to push to KVS
        startObservingDefaults()
    }

    // MARK: - Startup reconciliation

    /// True when this device has stored its own value for `key` (not just the default).
    private static func hasLocalValue<Value>(_ key: Defaults.Key<Value>) -> Bool {
        key.suite.object(forKey: key.name) != nil
    }

    private static func reconcileAtStartup(_ kvs: NSUbiquitousKeyValueStore) {
        let remoteSync = kvs.object(forKey: "iCloudSync") as? Bool
        switch startupAction(hasLocalValue: hasLocalValue(.iCloudSync), hasRemoteValue: remoteSync != nil) {
        case .adoptRemote: if let remoteSync { Defaults[.iCloudSync] = remoteSync }
        case .seedRemote: kvs.set(Defaults[.iCloudSync], forKey: "iCloudSync")
        case .keepLocal, .none: break
        }

        let remoteMode = (kvs.object(forKey: "iCloudSyncMode") as? String).flatMap(iCloudSyncMode.init(rawValue:))
        switch startupAction(hasLocalValue: hasLocalValue(.iCloudSyncMode), hasRemoteValue: remoteMode != nil) {
        case .adoptRemote: if let remoteMode { Defaults[.iCloudSyncMode] = remoteMode }
        case .seedRemote: kvs.set(Defaults[.iCloudSyncMode].rawValue, forKey: "iCloudSyncMode")
        case .keepLocal, .none: break
        }

        kvs.synchronize()
    }

    // MARK: - External change handler

    private static func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }

        // Only handle server changes and initial sync
        guard reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange else { return }

        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        let kvs = NSUbiquitousKeyValueStore.default
        for key in changedKeys {
            switch key {
            case "iCloudSync":
                if let value = kvs.object(forKey: key) as? Bool {
                    Defaults[.iCloudSync] = value
                }
            case "iCloudSyncMode":
                if let raw = kvs.object(forKey: key) as? String,
                   let mode = iCloudSyncMode(rawValue: raw) {
                    Defaults[.iCloudSyncMode] = mode
                }
            default:
                break
            }
        }
    }

    // MARK: - Local observation

    nonisolated(unsafe) private static var observations: [any Defaults.Observation] = []

    private static func startObservingDefaults() {
        let kvs = NSUbiquitousKeyValueStore.default

        observations.append(
            Defaults.observe(.iCloudSync, options: []) { change in
                kvs.set(change.newValue, forKey: "iCloudSync")
                kvs.synchronize()
            }
        )

        observations.append(
            Defaults.observe(.iCloudSyncMode, options: []) { change in
                kvs.set(change.newValue.rawValue, forKey: "iCloudSyncMode")
                kvs.synchronize()
            }
        )
    }
}
