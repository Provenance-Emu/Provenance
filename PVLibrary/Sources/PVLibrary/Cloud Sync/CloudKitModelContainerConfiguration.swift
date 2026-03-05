//
//  CloudKitModelContainerConfiguration.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Provides CloudKit-enabled ModelContainer configurations for Provenance's SwiftData
//  store, and documents the two-layer sync architecture.
//
//  ## Sync Architecture
//
//  Provenance uses two complementary CloudKit sync mechanisms:
//
//  ### 1. SwiftData native sync (this file)
//  Configured via `.cloudKitDatabase(.private(...))` in `ModelConfiguration`.
//  Uses `NSPersistentCloudKitContainer` under the hood (iOS 17+).
//  Automatically syncs *model property values* across devices:
//    - Game titles, ratings, play counts, import dates, artwork URLs
//    - Save state dates, core versions, auto-save flags
//    - System / BIOS / library metadata
//  Records land in the `iCloud.<containerID>.cloudkit` private zone.
//  Conflict resolution: last-writer-wins per property, based on `modificationDate`.
//
//  ### 2. Custom CKAsset sync  (CloudKitSyncer / CloudKitRomsSyncer / CloudKitSaveStatesSyncer)
//  Handles actual *binary file payloads* — ROM files, BIOS files, save state blobs.
//  SwiftData's native sync cannot carry large `CKAsset` values, so the custom
//  syncers remain required even after the SwiftData migration.
//  Records use deterministic IDs ("rom_<md5>", "savestate_<gameID>_<filename>")
//  in a separate custom zone and do NOT conflict with the native sync zone.
//
//  ## Existing CloudKit data
//  Records created by the Realm-based custom sync pipeline already exist in CloudKit
//  under the custom zone.  They are read by the custom syncers and are unaffected by
//  the SwiftData native sync, which operates in a different zone.
//
//  ## Merge conflicts
//  - Native sync path: `NSPersistentCloudKitContainer` handles merges automatically
//    using its built-in "remote wins" strategy on a per-property basis.
//  - Custom file sync path: Handled by `CloudKitConflictResolver` (unchanged).
//

#if canImport(SwiftData)
import SwiftData
import Foundation

/// Provides factory methods to create the Provenance SwiftData `ModelContainer`
/// with or without CloudKit metadata sync enabled.
///
/// Call `makeCloudKitEnabledContainer()` in production to enable both file sync
/// (via the custom CloudKitSyncer pipeline) and metadata sync (via SwiftData native).
/// Call `makeLocalContainer()` in tests, previews, or when iCloud is unavailable.
public enum CloudKitModelContainerConfiguration {

    /// The CloudKit container identifier used by the Provenance app.
    public static let containerIdentifier = "iCloud.org.provenance-emu.provenance"

    // MARK: - Factory methods

    /// Creates a `ModelContainer` with CloudKit metadata sync enabled.
    ///
    /// SwiftData will automatically sync all `@Model` property values to the
    /// user's private CloudKit database.  Large file payloads (ROMs, BIOS, save
    /// states) still require the separate custom `CloudKitSyncer` pipeline.
    ///
    /// - Parameters:
    ///   - cloudKitContainerIdentifier: Override the default CloudKit container ID.
    ///     Useful for enterprise or test containers.
    ///   - inMemory: Use an in-memory store.  Disables CloudKit sync implicitly.
    /// - Returns: A fully configured `ModelContainer`.
    /// - Throws: Any error thrown by `ModelContainer.init`.
    public static func makeCloudKitEnabledContainer(
        cloudKitContainerIdentifier: String = containerIdentifier,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: PVSwiftDataSchema.v1Schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(cloudKitContainerIdentifier)
        )
        return try ModelContainer(for: PVSwiftDataSchema.v1Schema, configurations: config)
    }

    /// Creates a `ModelContainer` without CloudKit sync (local storage only).
    ///
    /// Use this variant in:
    /// - Unit tests and SwiftUI previews (set `inMemory: true`)
    /// - Devices where iCloud is not signed in
    /// - When the user has disabled CloudKit sync in Settings
    ///
    /// - Parameter inMemory: Use an in-memory store.
    /// - Returns: A local-only `ModelContainer`.
    public static func makeLocalContainer(inMemory: Bool = false) throws -> ModelContainer {
        return try PVSwiftDataSchema.makePVModelContainer(inMemory: inMemory)
    }
}

#endif
