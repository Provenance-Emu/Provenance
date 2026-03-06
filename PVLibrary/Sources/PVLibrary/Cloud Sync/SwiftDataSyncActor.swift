//
//  SwiftDataSyncActor.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  SwiftData-backed ModelActor for CloudKit sync operations.
//  This is the SwiftData counterpart of RealmActor / RealmContext.
//  Designed to be injected into CloudKit syncers as part of the
//  Realm → SwiftData migration (see epic #2510).
//
//  ## Architecture note
//
//  The custom CKAsset-based sync pipeline (CloudKitSyncer, CloudKitRomsSyncer,
//  CloudKitSaveStatesSyncer) handles *file* payloads and MUST remain in place;
//  SwiftData's native `.cloudKitDatabase` sync only carries model *properties*,
//  not large binary assets.  This actor provides thread-safe model context access
//  so that the custom syncers can query and update SwiftData models without
//  crossing actor boundaries unsafely.
//

#if canImport(SwiftData)
import SwiftData
import Foundation
import PVLogging

/// A `@ModelActor` that provides thread-safe SwiftData model context access for
/// CloudKit sync operations.
///
/// Obtain a shared instance via `SwiftDataSyncActor(modelContainer:)` and call
/// methods from any async context.  All mutations are automatically serialised
/// through the underlying `ModelContext` / `DefaultSerialModelExecutor`.
///
/// Usage:
/// ```swift
/// let syncActor = SwiftDataSyncActor(modelContainer: container)
/// let game = try await syncActor.fetchGame(md5: someMD5)
/// try await syncActor.markGameSynced(md5: someMD5, recordID: "rom_\(someMD5)")
/// ```
@ModelActor
public actor SwiftDataSyncActor {

    // MARK: - Game queries

    /// Fetch a `Game_Data` model by its ROM MD5 hash.
    ///
    /// The input is normalised to uppercase before comparison to match
    /// the storage convention (hashes are stored uppercased on insert).
    /// - Returns: The matching game or `nil` if not found.
    public func fetchGame(md5: String) throws -> Game_Data? {
        let normalizedMD5 = md5.uppercased()
        var descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.md5Hash == normalizedMD5 }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch all `Game_Data` models that do not yet have a confirmed CloudKit asset.
    public func fetchGamesNeedingUpload() throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.hasCloudAssets != true }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all `Game_Data` models that have a CloudKit record but whose file
    /// has not yet been downloaded to this device.
    ///
    /// `isDownloaded` is `@Transient` (not persisted), so the cloudRecordID filter
    /// runs in-database while the isDownloaded check is applied in memory.
    public func fetchGamesNeedingDownload() throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.cloudRecordID != nil }
        )
        return try modelContext.fetch(descriptor).filter { !$0.isDownloaded }
    }

    /// Mark a game as fully synced to CloudKit.
    /// Sets `cloudRecordID`, `hasCloudAssets`, and `lastCloudSyncDate`.
    public func markGameSynced(md5: String, recordID: String) throws {
        guard let game = try fetchGame(md5: md5) else {
            WLOG("SwiftDataSyncActor.markGameSynced: no game found for md5=\(md5)")
            return
        }
        game.cloudRecordID = recordID
        game.hasCloudAssets = true
        game.lastCloudSyncDate = Date()
        try modelContext.save()
    }

    /// Update metadata fields on a `Game_Data` model from a CloudKit record.
    /// The closure receives the live SwiftData model instance and may mutate it freely;
    /// `save()` is called automatically after the closure returns.
    ///
    /// The closure is `@Sendable` to prevent accidental capture of non-sendable state
    /// across the actor boundary.
    public func updateGameMetadata(md5: String, update: @Sendable (Game_Data) -> Void) throws {
        guard let game = try fetchGame(md5: md5) else {
            WLOG("SwiftDataSyncActor.updateGameMetadata: no game found for md5=\(md5)")
            return
        }
        update(game)
        try modelContext.save()
    }

    // MARK: - SaveState queries

    /// Fetch a `SaveState_Data` model by its unique ID.
    public func fetchSaveState(id: String) throws -> SaveState_Data? {
        var descriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch all save states for a given game that have not yet been uploaded.
    ///
    /// Note: optional-chaining (`state.game?.id`) is not reliably supported in
    /// SwiftData `#Predicate` expressions, so we fetch all unsynced save states
    /// and filter by game ID in memory.
    public func fetchSaveStatesNeedingUpload(gameID: String) throws -> [SaveState_Data] {
        let descriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate<SaveState_Data> { state in
                state.cloudRecordID == nil
            }
        )
        let unsynced = try modelContext.fetch(descriptor)
        return unsynced.filter { $0.game?.id == gameID }
    }

    /// Mark a save state as fully synced to CloudKit.
    public func markSaveStateSynced(id: String, recordID: String) throws {
        guard let state = try fetchSaveState(id: id) else {
            WLOG("SwiftDataSyncActor.markSaveStateSynced: no save state found for id=\(id)")
            return
        }
        state.cloudRecordID = recordID
        state.lastCloudSyncDate = Date()
        try modelContext.save()
    }

    // MARK: - BIOS queries

    /// Fetch a `BIOS_Data` model by its expected MD5 hash (case-insensitive).
    public func fetchBIOS(md5: String) throws -> BIOS_Data? {
        let md5Upper = md5.uppercased()
        var descriptor = FetchDescriptor<BIOS_Data>(
            predicate: #Predicate { $0.expectedMD5 == md5Upper }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Context helpers

    /// Explicitly flush pending changes to the persistent store.
    public func saveContext() throws {
        try modelContext.save()
    }
}

#endif
