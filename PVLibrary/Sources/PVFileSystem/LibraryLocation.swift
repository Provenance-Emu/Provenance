//
//  LibraryLocation.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Where the library's files live: ROMs, BIOS, System, save states, battery saves,
//  screenshots, cheats and patches (everything under `Paths` built on
//  `URL.documentsiCloudOrLocalPath`). The app's own files (Imports, core configs) stay
//  under `URL.documentsPath`, which follows the same App Group precedence.
//
//  The appGroup/appStorage axis is fixed per process (`storedAtLaunch`), like
//  `URL.documentsPath`: a switch written by `LibraryMoveEngine` takes effect at the next
//  launch. The iCloud Drive axis is still derived live from the iCloud settings (phase 5).
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md
//

import Foundation
import Defaults
import PVSettings

public enum LibraryLocation: String, Sendable, CaseIterable {
    /// The app's Documents (Caches on tvOS). The default.
    case appStorage
    /// The App Group container's Documents (legacy; a valid move source, never a destination).
    case appGroup
    /// The iCloud Drive ubiquity container's Documents.
    case iCloudDrive

    /// userInfo key of `.libraryLocationDidChange`: `true` when the new location applies at the next launch.
    public static let requiresRelaunchUserInfoKey = "requiresRelaunch"

    /// The `libraryLocation` setting as it was when this process first asked. Read once so the
    /// library root and `URL.documentsPath` can't drift apart mid-session.
    static let storedAtLaunch: LibraryLocation? = Defaults[.libraryLocation].flatMap(LibraryLocation.init(rawValue:))

    /// The legacy `useAppGroups` toggle as it was when this process first asked. Snapshotted like
    /// `storedAtLaunch`: `switchStored(to:)` rewrites the toggle, and the running process must not follow.
    static let useAppGroupsAtLaunch: Bool = Defaults[.useAppGroups]

    /// `true` when this process' Documents and Caches live in the App Group container.
    /// The stored location wins; the legacy `useAppGroups` toggle is the fallback. Fixed per process.
    public static var usesAppGroupContainer: Bool {
        #if os(tvOS)
        return false
        #else
        return usesAppGroupContainer(stored: storedAtLaunch, useAppGroupsAtLaunch: useAppGroupsAtLaunch)
        #endif
    }

    /// A stored `.iCloudDrive` is not honoured until phase 5 (see `resolve`), so it counts as unset here too.
    static func usesAppGroupContainer(stored: LibraryLocation?, useAppGroupsAtLaunch: Bool) -> Bool {
        if let stored, stored != .iCloudDrive { return stored == .appGroup }
        return useAppGroupsAtLaunch
    }

    /// The location this process uses. The appGroup/appStorage axis is the launch snapshot; only the
    /// iCloud Drive axis follows the live iCloud settings.
    public static var current: LibraryLocation {
        #if os(tvOS)
        return .appStorage
        #else
        return resolve(stored: storedAtLaunch,
                       useAppGroups: useAppGroupsAtLaunch,
                       iCloudSync: Defaults[.iCloudSync],
                       iCloudDriveMode: Defaults[.iCloudSyncMode].isICloudDrive)
        #endif
    }

    /// iCloud Drive mode only applies while iCloud sync is on, and wins over everything else.
    /// A stored location (written by the move engine) wins over the legacy `useAppGroups` toggle.
    /// A stored `.iCloudDrive` is not honoured until phase 5 moves the iCloud axis into the setting.
    static func resolve(stored: LibraryLocation?, useAppGroups: Bool, iCloudSync: Bool, iCloudDriveMode: Bool) -> LibraryLocation {
        if iCloudSync && iCloudDriveMode { return .iCloudDrive }
        if let stored, stored != .iCloudDrive { return stored }
        return useAppGroups ? .appGroup : .appStorage
    }

    /// The folder the library's subfolders (`ROMs/`, `BIOS/`, …) live in.
    /// Call on a background thread: the iCloud container lookup can block.
    public var rootURL: URL {
        #if os(tvOS)
        return URL.cachesPath
        #else
        return rootURL(localDocuments: URL.documentsPathLocal,
                       appGroupDocuments: URL.documentsPathAppGroup,
                       iCloudDocuments: self == .iCloudDrive ? URL.iCloudDocumentsDirectory : nil,
                       usesAppGroupContainer: Self.usesAppGroupContainer)
        #endif
    }

    /// Each location names its own root. iCloud Drive without a container falls back to the
    /// app-files root (the group's Documents for an App Group user, else local Documents).
    func rootURL(localDocuments: URL, appGroupDocuments: URL?, iCloudDocuments: URL?, usesAppGroupContainer: Bool) -> URL {
        switch self {
        case .appStorage:
            return localDocuments
        case .appGroup:
            return appGroupDocuments ?? localDocuments
        case .iCloudDrive:
            return iCloudDocuments ?? (usesAppGroupContainer ? appGroupDocuments : nil) ?? localDocuments
        }
    }

    /// Records `location` as the library location. Only `LibraryMoveEngine` calls this, after the
    /// copy is verified. Mirrors the legacy toggle so a build that only knows `useAppGroups` agrees.
    /// Takes effect at the next launch (see `storedAtLaunch`).
    public static func switchStored(to location: LibraryLocation) {
        Defaults[.libraryLocation] = location.rawValue
        Defaults[.useAppGroups] = (location == .appGroup)
        NotificationCenter.default.post(name: .libraryLocationDidChange, object: nil,
                                        userInfo: [requiresRelaunchUserInfoKey: true])
    }
}

public extension Notification.Name {
    /// Posted by `LibraryLocation.switchStored(to:)`. userInfo: `LibraryLocation.requiresRelaunchUserInfoKey`.
    static let libraryLocationDidChange = Notification.Name("PVLibraryLocationDidChangeNotification")
}
