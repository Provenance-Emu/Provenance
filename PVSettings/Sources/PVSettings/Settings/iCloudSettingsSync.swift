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

    /// Key used to detect a fresh install (set after first successful sync).
    private static let sentinelKey = "org.provenance.settings.iCloudKVS.initialized"

    // MARK: - Public API

    /// Call once at app launch (e.g. in AppDelegate or App.init).
    /// Restores settings from iCloud KVS if this is a fresh install,
    /// then starts observing local changes to push them to KVS.
    public static func setup() {
        let kvs = NSUbiquitousKeyValueStore.default

        // Pull latest from iCloud
        kvs.synchronize()

        // Detect fresh install: sentinel key missing from UserDefaults
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: sentinelKey)

        if isFirstLaunch {
            restoreFromKVS(kvs)
            UserDefaults.standard.set(true, forKey: sentinelKey)
        }

        // Push current values to KVS (in case this is an upgrade or first install)
        pushToKVS(kvs)

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

    // MARK: - Restore

    private static func restoreFromKVS(_ kvs: NSUbiquitousKeyValueStore) {
        // iCloudSync
        if let syncValue = kvs.object(forKey: "iCloudSync") as? Bool {
            Defaults[.iCloudSync] = syncValue
        }

        // iCloudSyncMode (stored as String raw value)
        if let modeRaw = kvs.object(forKey: "iCloudSyncMode") as? String,
           let mode = iCloudSyncMode(rawValue: modeRaw) {
            Defaults[.iCloudSyncMode] = mode
        }
    }

    // MARK: - Push

    private static func pushToKVS(_ kvs: NSUbiquitousKeyValueStore) {
        kvs.set(Defaults[.iCloudSync], forKey: "iCloudSync")
        kvs.set(Defaults[.iCloudSyncMode].rawValue, forKey: "iCloudSyncMode")
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
