//
//  ProvenanceSnapshot.swift
//  PVLibrarySnapshotConfig
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provenance's settings for the shared PVLibrarySnapshot package
//  (github.com/Provenance-Emu/PVLibrarySnapshot, also used by iCube and iFly).
//  The app writes the snapshot and mirrors covers into the App Group; Top Shelf
//  only reads. Both sides build their configuration here, so they always agree
//  on the group, the media folder and the launch URL.
//
//  No PVLibrary, PVPrimitives or UIKit: app extensions link this module.
//

import Foundation
@_exported import PVLibrarySnapshot

public enum ProvenanceSnapshot {
    /// Used when a build does not set `APP_GROUP_IDENTIFIER` (development, CI).
    /// Matches the fallback of `PVAppGroupId` in PVFileSystem.
    static let fallbackAppGroupIdentifier = "group.org.provenance-emu.provenance"

    /// `provenance://open?md5=<md5>`, which `ProvenanceApp.onOpenURL` routes to
    /// the game. Mirrors `ProvenanceDeepLink` in PVPrimitives; duplicated so
    /// extensions don't link PVPrimitives.
    static let launchURLScheme = "provenance"
    static let launchURLHost = "open"
    static let launchURLQueryItem = "md5"

    static let telemetrySubsystem = "org.provenance-emu.provenance"

    /// The configuration for the running build.
    public static let configuration = makeConfiguration(
        appGroupIdentifier: resolveAppGroupIdentifier(Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String)
    )

    public static let appGroup = LibrarySnapshotAppGroup(configuration: configuration)

    public static var store: LibrarySnapshotStore { LibrarySnapshotStore(appGroup: appGroup) }

    static func makeConfiguration(appGroupIdentifier: String) -> LibrarySnapshotConfiguration {
        LibrarySnapshotConfiguration(
            appGroupIdentifier: appGroupIdentifier,
            launchURLScheme: launchURLScheme,
            launchURLHost: launchURLHost,
            launchURLQueryItem: launchURLQueryItem,
            telemetrySubsystem: telemetrySubsystem
        )
    }

    /// The `APP_GROUP_IDENTIFIER` Info.plist value, which sideloaders change with
    /// their team. Empty values and unexpanded `$(…)` placeholders fall back.
    static func resolveAppGroupIdentifier(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty, !raw.contains("$(") else { return fallbackAppGroupIdentifier }
        return raw
    }
}

public extension ExtensionTelemetry {
    init(_ surface: Surface) {
        self.init(surface, subsystem: ProvenanceSnapshot.configuration.telemetrySubsystem)
    }
}

public extension LibrarySnapshotGame {
    var launchURL: URL? { launchURL(using: ProvenanceSnapshot.configuration) }
    var coverURL: URL? { coverURL(in: ProvenanceSnapshot.appGroup) }
}
