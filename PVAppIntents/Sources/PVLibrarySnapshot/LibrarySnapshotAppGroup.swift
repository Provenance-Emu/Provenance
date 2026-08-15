//
//  LibrarySnapshotAppGroup.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  App Group resolution for the library snapshot.
//
//  This module intentionally has NO dependencies (no Realm, no PVLibrary, no
//  UIKit) so that any app extension can link it and read library data without
//  opening the Realm database.
//
//  The canonical definition used by code that *can* import PVLibrary is:
//      PVLibrary/Sources/PVFileSystem/Paths.swift  →  `public let PVAppGroupId`
//  Both read the same `APP_GROUP_IDENTIFIER` Info.plist key, so the value is
//  always correct for the running build.
//

import Foundation

/// App Group access for snapshot readers and writers.
public enum LibrarySnapshotAppGroup {
    /// Fallback used by development and CI builds that do not set the
    /// `APP_GROUP_IDENTIFIER` build setting.
    private static let fallbackIdentifier = "group.org.provenance-emu.provenance"

    /// The App Group identifier for this build, resolved from Info.plist.
    public static let identifier: String = {
        let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
        // Guard against unexpanded Xcode build-variable placeholders (e.g. "$(APP_GROUP_IDENTIFIER)")
        // which appear when a target's Info.plist is evaluated outside of an Xcode build.
        guard let raw, !raw.isEmpty, !raw.contains("$(") else {
            return fallbackIdentifier
        }
        return raw
    }()

    /// The shared App Group `UserDefaults` suite, or `nil` when the entitlement
    /// is missing.  Callers must degrade to an empty state rather than falling
    /// back to `.standard`, which would silently mask a configuration problem.
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// The App Group container root, or `nil` when the entitlement is missing.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Resolves a snapshot-relative path (e.g. `Documents/PVCache/<hash>`) to an
    /// absolute URL inside the App Group container.
    public static func url(forRelativePath path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        return containerURL?.appendingPathComponent(path)
    }
}
