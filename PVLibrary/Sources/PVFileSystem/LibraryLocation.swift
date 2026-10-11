//
//  LibraryLocation.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Where the library's files live: ROMs, BIOS, System, save states, battery saves,
//  screenshots, cheats and patches (everything under `Paths` built on
//  `URL.documentsiCloudOrLocalPath`). The app's own files (Imports, core configs) stay
//  under `URL.documentsPath` whatever the location.
//
//  Not stored yet: derived from the settings that choose it today, so it can't disagree
//  with them. Storing it comes with the move engine that owns switching
//  (docs/superpowers/specs/2026-10-11-library-storage-locations-design.md).
//

import Foundation
import Defaults
import PVSettings

public enum LibraryLocation: Sendable {
    /// The app's Documents (Caches on tvOS). The default.
    case appStorage
    /// The App Group container's Documents (the legacy `useAppGroups` setting).
    case appGroup
    /// The iCloud Drive ubiquity container's Documents.
    case iCloudDrive

    /// The location the current settings select.
    public static var current: LibraryLocation {
        #if os(tvOS)
        return .appStorage
        #else
        return resolve(useAppGroups: URL.USE_APP_GROUPS,
                       iCloudSync: Defaults[.iCloudSync],
                       iCloudDriveMode: Defaults[.iCloudSyncMode].isICloudDrive)
        #endif
    }

    /// iCloud Drive mode only applies while iCloud sync is on, and wins over App Group storage.
    static func resolve(useAppGroups: Bool, iCloudSync: Bool, iCloudDriveMode: Bool) -> LibraryLocation {
        if iCloudSync && iCloudDriveMode { return .iCloudDrive }
        return useAppGroups ? .appGroup : .appStorage
    }

    /// The folder the library's subfolders (`ROMs/`, `BIOS/`, …) live in.
    /// Call on a background thread: the iCloud container lookup can block.
    public var rootURL: URL {
        rootURL(documents: URL.documentsPath,
                iCloudDocuments: self == .iCloudDrive ? URL.iCloudDocumentsDirectory : nil)
    }

    /// App Group storage is already folded into `documents` (`URL.documentsPath` picks the
    /// group container at launch). iCloud Drive falls back to it when there is no container.
    func rootURL(documents: URL, iCloudDocuments: URL?) -> URL {
        switch self {
        case .appStorage, .appGroup:
            return documents
        case .iCloudDrive:
            return iCloudDocuments ?? documents
        }
    }
}
