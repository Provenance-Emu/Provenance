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
    /// A folder the user picked in Files, reached through a security-scoped bookmark (`PickedLibraryFolder`).
    case pickedFolder

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

    /// The appGroup/appStorage/pickedFolder axis this process launched on. Unlike `current` it ignores the live
    /// iCloud Drive setting. The move engine starts and resumes against this.
    public static var launchAxis: LibraryLocation {
        #if os(tvOS)
        return .appStorage
        #else
        if storedAtLaunch == .pickedFolder { return .pickedFolder }
        return usesAppGroupContainer ? .appGroup : .appStorage
        #endif
    }

    // MARK: - Picked folder

    /// Resolved once per process from the stored bookmark (D9). The access it starts is never stopped.
    public static let pickedFolderAtLaunch: PickedFolderLaunchState = {
        #if os(tvOS)
        return .notConfigured
        #else
        guard storedAtLaunch == .pickedFolder else { return .notConfigured }
        let store = PickedLibraryFolderStore.shared
        return launchState(folder: store.load(), store: store)
        #endif
    }()

    /// Whether the picked folder also holds the saves folders. `true` for every other location (one root).
    static let pickedFolderIncludesSavesAtLaunch: Bool = {
        guard storedAtLaunch == .pickedFolder else { return true }
        return PickedLibraryFolderStore.shared.load()?.includesSaves ?? false
    }()

    /// Resolves `folder`; a stale bookmark is re-saved through `store`. Pure apart from that write.
    static func launchState(folder: PickedLibraryFolder?, store: PickedLibraryFolderStore) -> PickedFolderLaunchState {
        guard let folder else { return .unavailable(reason: "No library folder is saved.") }
        do {
            let resolution = try LibraryFolderBookmark.resolve(folder.bookmark)
            if resolution.isStale, let fresh = try? LibraryFolderBookmark.make(from: resolution.url) {
                var refreshed = folder
                refreshed.bookmark = fresh
                try? store.save(refreshed)
            }
            return .available(resolution.url)
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    /// Roots `RelativeRoot.createRelativePath` strips before pattern matching (Task 4).
    public static var pickedRootsAtLaunch: [URL] {
        pickedFolderAtLaunch.url.map { [$0] } ?? []
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
                       pickedFolder: self == .pickedFolder ? Self.pickedFolderAtLaunch.url : nil,
                       usesAppGroupContainer: Self.usesAppGroupContainer)
        #endif
    }

    /// Each location names its own root. iCloud Drive without a container falls back to the
    /// app-files root (the group's Documents for an App Group user, else local Documents).
    /// An unavailable picked folder falls back to local Documents so nothing crashes; the UI reports it (D9).
    func rootURL(localDocuments: URL, appGroupDocuments: URL?, iCloudDocuments: URL?, pickedFolder: URL? = nil, usesAppGroupContainer: Bool) -> URL {
        switch self {
        case .appStorage:
            return localDocuments
        case .appGroup:
            return appGroupDocuments ?? localDocuments
        case .iCloudDrive:
            return iCloudDocuments ?? (usesAppGroupContainer ? appGroupDocuments : nil) ?? localDocuments
        case .pickedFolder:
            return pickedFolder ?? localDocuments
        }
    }

    /// Where the saves folders live: the app-files root for a picked folder without saves, else the library root (D10).
    public var savesRootURL: URL {
        #if os(tvOS)
        return rootURL
        #else
        return savesRootURL(rootURL: rootURL, appFilesRoot: URL.documentsPath, includesSaves: Self.pickedFolderIncludesSavesAtLaunch)
        #endif
    }

    func savesRootURL(rootURL: URL, appFilesRoot: URL, includesSaves: Bool) -> URL {
        self == .pickedFolder && !includesSaves ? appFilesRoot : rootURL
    }

    /// The root a partial path resolves against: the library root for `ROMs/`, `BIOS/`, `System/`, the saves root otherwise.
    public static func root(forPartialPath partialPath: String) -> URL {
        let current = LibraryLocation.current
        return root(forPartialPath: partialPath, libraryRoot: current.rootURL, savesRoot: current.savesRootURL)
    }

    static func root(forPartialPath partialPath: String, libraryRoot: URL, savesRoot: URL) -> URL {
        LibraryMoveFolders.isShared(partialPath: partialPath) ? libraryRoot : savesRoot
    }

    /// Records the library location. Only `LibraryMoveEngine` (and the picked-folder recovery actions) call this.
    /// `pickedFolder` is required for `.pickedFolder` and cleared for every other location, so the stored
    /// bookmark can never outlive the location that uses it. Mirrors the legacy toggle. Applies at the next launch.
    public static func switchStored(to location: LibraryLocation, pickedFolder: PickedLibraryFolder? = nil) throws {
        if location == .pickedFolder {
            guard let pickedFolder else { throw LibraryFolderError.missingPickedFolder }
            try PickedLibraryFolderStore.shared.save(pickedFolder)
        } else {
            PickedLibraryFolderStore.shared.clear()
        }
        Defaults[.libraryLocation] = location.rawValue
        Defaults[.useAppGroups] = (location == .appGroup)
        NotificationCenter.default.post(name: .libraryLocationDidChange, object: nil,
                                        userInfo: [requiresRelaunchUserInfoKey: true])
    }
}

/// What `LibraryLocation.pickedFolderAtLaunch` found.
public enum PickedFolderLaunchState: Sendable, Equatable {
    /// The stored location is not `.pickedFolder`.
    case notConfigured
    case available(URL)
    /// The folder was deleted, iCloud signed out, the provider removed, or the stored value is missing.
    case unavailable(reason: String)

    public var url: URL? {
        if case .available(let url) = self { return url }
        return nil
    }

    public var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}

public extension Notification.Name {
    /// Posted by `LibraryLocation.switchStored(to:pickedFolder:)`. userInfo: `LibraryLocation.requiresRelaunchUserInfoKey`.
    static let libraryLocationDidChange = Notification.Name("PVLibraryLocationDidChangeNotification")
}
