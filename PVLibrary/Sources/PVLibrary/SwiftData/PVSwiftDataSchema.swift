//
//  PVSwiftDataSchema.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Defines the SwiftData ModelContainer schema and versioned migration plan
//  for the Provenance game library.
//
//  CloudKit Integration Notes:
//  - SwiftData uses NSPersistentCloudKitContainer under the hood when
//    `cloudKitContainerIdentifier` is set on ModelConfiguration.
//  - This automatically syncs @Model metadata (game info, favorites, ratings,
//    save state metadata) between devices via CloudKit's private database.
//  - Binary file assets (ROM files, save state files, BIOS files) are NOT
//    synced via SwiftData CloudKit — those continue to use the per-directory
//    file syncers (CloudKitRomsSyncer, CloudKitSaveStatesSyncer, etc.).
//  - Merge conflict strategy: SwiftData CloudKit sync uses field-level
//    last-write-wins semantics for model properties.
//  - The `cloudKitContainerIdentifier` must match the entitlement in the app
//    target (e.g. "iCloud.org.provenance-emu.provenance").

import SwiftData

/// The full schema for Provenance's SwiftData store — version 1.
///
/// All @Model types must be listed here. The container is configured via
/// `makePVModelContainer` or `makePVModelContainerWithCloudKit`.
public enum PVSwiftDataSchema {
    /// Schema v1: initial SwiftData migration from Realm.
    public static let v1Schema = Schema([
        Game_Data.self,
        System_Data.self,
        SaveState_Data.self,
        Core_Data.self,
        BIOS_Data.self,
        Cheats_Data.self,
        File_Data.self,
        ImageFile_Data.self,
        Library_Data.self,
        RecentGame_Data.self,
        User_Data.self,
    ])

    /// Creates and returns the shared `ModelContainer` for the Provenance library
    /// **without** CloudKit sync (local storage only).
    ///
    /// For a CloudKit-enabled container use `CloudKitModelContainerConfiguration`
    /// or the convenience overload `makePVModelContainer(cloudKit:inMemory:)`.
    ///
    /// - Parameter inMemory: When `true` the container uses an in-memory store
    ///   (useful for previews and unit tests).
    public static func makePVModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: v1Schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: v1Schema, configurations: config)
    }

    /// Creates the production `ModelContainer`, optionally enabling CloudKit
    /// metadata sync via `NSPersistentCloudKitContainer`.
    ///
    /// When `cloudKit` is `true`, SwiftData automatically syncs model *properties*
    /// (titles, ratings, play counts, etc.) to the user's private CloudKit database.
    /// Binary file payloads (ROMs, BIOS, save states) still require the separate
    /// custom `CloudKitSyncer` pipeline regardless of this flag.
    ///
    /// - Parameters:
    ///   - cloudKit: Enable SwiftData native CloudKit metadata sync.
    ///   - inMemory: Use an in-memory store (disables CloudKit implicitly).
    public static func makePVModelContainer(
        cloudKit: Bool,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        if cloudKit {
            return try CloudKitModelContainerConfiguration.makeCloudKitEnabledContainer(inMemory: inMemory)
        } else {
            return try makePVModelContainer(inMemory: inMemory)
        }
    }

    /// Creates a `ModelContainer` backed by CloudKit for automatic metadata sync.
    ///
    /// SwiftData's built-in CloudKit support (via `NSPersistentCloudKitContainer`)
    /// automatically syncs model metadata between devices. Only structured model
    /// data is synced; binary ROM/save-state files still use the file-based syncers.
    ///
    /// - Parameters:
    ///   - cloudKitContainerIdentifier: The CloudKit container identifier, e.g.
    ///     `"iCloud.org.provenance-emu.provenance"`. Defaults to the standard
    ///     Provenance container.
    ///   - inMemory: When `true` returns an in-memory store (useful for unit tests).
    ///
    /// - Returns: A `ModelContainer` configured with CloudKit sync.
    /// - Throws: If the container cannot be created (e.g. entitlement missing).
    public static func makePVModelContainerWithCloudKit(
        cloudKitContainerIdentifier: String = CloudKitModelContainerConfiguration.containerIdentifier,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: v1Schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(cloudKitContainerIdentifier)
        )
        return try ModelContainer(for: v1Schema, configurations: config)
    }

    /// Delete all objects for every tracked model type from the given context and save.
    ///
    /// Centralised here so that `SwiftDataDatabaseDriver` and `SwiftDataDatabaseActor`
    /// share a single authoritative list, preventing drift as the schema evolves.
    public static func deleteAll(from context: ModelContext) throws {
        try context.delete(model: Game_Data.self)
        try context.delete(model: System_Data.self)
        try context.delete(model: SaveState_Data.self)
        try context.delete(model: RecentGame_Data.self)
        try context.delete(model: Core_Data.self)
        try context.delete(model: BIOS_Data.self)
        try context.delete(model: Cheats_Data.self)
        try context.delete(model: File_Data.self)
        try context.delete(model: ImageFile_Data.self)
        try context.delete(model: Library_Data.self)
        try context.delete(model: User_Data.self)
        try context.save()
    }
}
