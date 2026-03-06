//
//  SwiftDataDatabaseDriver.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-05.
//
//  Implements DatabaseDriver backed by SwiftData ModelContext.
//  Conforms synchronously to the DatabaseDriver protocol; a separate
//  ModelActor (`SwiftDataDatabaseActor`) is provided for async/concurrent use.
//

#if canImport(SwiftData)
import SwiftData
import Foundation
import PVLogging

// MARK: - SwiftDataDatabaseDriver

/// Synchronous `DatabaseDriver` implementation backed by a SwiftData `ModelContext`.
///
/// The `ModelContext` is not thread-safe; callers must ensure all accesses happen on
/// the same thread (typically the main thread for UI-driven code).
/// For concurrent/async use, prefer `SwiftDataDatabaseActor`.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
public final class SwiftDataDatabaseDriver: DatabaseDriver {

    // MARK: DatabaseDriverDataTypes

    public typealias GameType = Game_Data
    public typealias SystemType = System_Data
    public typealias SaveType = SaveState_Data
    public typealias RecentGameType = RecentGame_Data

    // MARK: Storage

    public let modelContainer: ModelContainer
    /// Model context for synchronous operations.
    ///
    /// - Important: `ModelContext` is not thread-safe. All accesses must happen on the
    ///   thread that created this driver (typically the main thread for UI code).
    ///   Use `SwiftDataDatabaseActor` for concurrent/background access.
    public let modelContext: ModelContext

    /// `true` when the driver is backed by a persistent on-disk store.
    /// `false` when the driver fell back to an in-memory store due to a container
    /// creation failure — data will not survive app restarts in this state.
    public let isUsingPersistentStore: Bool

    // MARK: Init

    /// Designated initialiser. The `database` parameter is ignored — SwiftData manages
    /// its own container independently from Realm.
    public required init(database _: RomDatabase) {
        do {
            let container = try PVSwiftDataSchema.makePVModelContainer()
            self.modelContainer = container
            self.modelContext = ModelContext(container)
            self.isUsingPersistentStore = true
        } catch {
            ELOG("SwiftDataDatabaseDriver: failed to create persistent ModelContainer — \(error)")
            // Non-fatal fallback: use an in-memory container so the app can continue.
            // isUsingPersistentStore will be false — callers can detect this and warn users.
            if let inMemoryContainer = try? PVSwiftDataSchema.makePVModelContainer(inMemory: true) {
                WLOG("SwiftDataDatabaseDriver: falling back to in-memory ModelContainer; data will not be persisted across launches")
                self.modelContainer = inMemoryContainer
                self.modelContext = ModelContext(inMemoryContainer)
                self.isUsingPersistentStore = false
            } else {
                // All fallback attempts failed; crash with a clear diagnostic.
                fatalError("SwiftDataDatabaseDriver: unable to create any ModelContainer: \(error)")
            }
        }
    }

    /// Convenience initialiser for testing or standalone use.
    /// - Parameter inMemory: When `true`, data is stored only in memory (useful for tests).
    public init(inMemory: Bool = false) throws {
        let container = try PVSwiftDataSchema.makePVModelContainer(inMemory: inMemory)
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        self.isUsingPersistentStore = !inMemory
    }

    // MARK: - DatabaseDriver protocol

    /// Fetch a game by its MD5 hash identifier, matching the Realm driver semantics.
    /// - Parameter identifier: The game's `md5Hash` value.
    public func game(identifier: String) -> Game_Data? {
        var descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.md5Hash == identifier }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            ELOG("SwiftDataDatabaseDriver.game(identifier:) failed: \(error)")
            return nil
        }
    }

    /// Fetch a system by its unique identifier.
    public func system(identifier: String) -> System_Data? {
        var descriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            ELOG("SwiftDataDatabaseDriver.system(identifier:) failed: \(error)")
            return nil
        }
    }
}

// MARK: - CRUD helpers

@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
public extension SwiftDataDatabaseDriver {

    // MARK: Insert

    /// Insert a new `Game_Data` record and save immediately.
    public func insert(game: Game_Data) throws {
        modelContext.insert(game)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: inserted game '\(game.title)' (\(game.id))")
    }

    /// Insert a new `System_Data` record and save immediately.
    public func insert(system: System_Data) throws {
        modelContext.insert(system)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: inserted system '\(system.name)' (\(system.identifier))")
    }

    /// Insert a new `SaveState_Data` record and save immediately.
    public func insert(saveState: SaveState_Data) throws {
        modelContext.insert(saveState)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: inserted save state \(saveState.id)")
    }

    /// Insert a new `RecentGame_Data` record and save immediately.
    public func insert(recentGame: RecentGame_Data) throws {
        modelContext.insert(recentGame)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: inserted recent game \(recentGame.id)")
    }

    // MARK: Fetch all

    /// Fetch all games, optionally sorted by a key path.
    public func allGames(sortedBy sortDescriptors: [SortDescriptor<Game_Data>] = []) throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all systems, optionally sorted.
    public func allSystems(sortedBy sortDescriptors: [SortDescriptor<System_Data>] = []) throws -> [System_Data] {
        let descriptor = FetchDescriptor<System_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all save states, optionally sorted.
    public func allSaveStates(sortedBy sortDescriptors: [SortDescriptor<SaveState_Data>] = []) throws -> [SaveState_Data] {
        let descriptor = FetchDescriptor<SaveState_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all recent games, optionally sorted.
    public func allRecentGames(sortedBy sortDescriptors: [SortDescriptor<RecentGame_Data>] = []) throws -> [RecentGame_Data] {
        let descriptor = FetchDescriptor<RecentGame_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    // MARK: Filtered fetch

    /// Fetch games matching a predicate.
    public func games(matching predicate: Predicate<Game_Data>,
               sortedBy sortDescriptors: [SortDescriptor<Game_Data>] = []) throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(predicate: predicate, sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch games for a given system identifier.
    public func games(forSystemIdentifier systemIdentifier: String) throws -> [Game_Data] {
        try games(
            matching: #Predicate { $0.systemIdentifier == systemIdentifier },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Fetch favorite games sorted by title.
    public func favoriteGames() throws -> [Game_Data] {
        try games(
            matching: #Predicate { $0.isFavorite == true },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Search for games whose title contains `searchText` (case-insensitive).
    ///
    /// A store-side predicate using `contains` is applied first as a coarse filter,
    /// then an in-memory case-insensitive pass narrows the results. This avoids
    /// fetching the entire game library while working around SwiftData's lack of
    /// support for `lowercased()` inside `#Predicate`.
    public func searchGames(for searchText: String) throws -> [Game_Data] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return try allGames(sortedBy: [SortDescriptor(\.title)]) }
        let coarse = try games(
            matching: #Predicate { game in game.title.contains(trimmed) },
            sortedBy: [SortDescriptor(\.title)]
        )
        let lower = trimmed.lowercased()
        return coarse.filter { $0.title.lowercased().contains(lower) }
    }

    // MARK: Batch insert

    /// Insert multiple games in a single save operation (more efficient than repeated `insert(game:)`).
    public func insertBatch(games: [Game_Data]) throws {
        for game in games { modelContext.insert(game) }
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: batch-inserted \(games.count) game(s)")
    }

    /// Insert multiple systems in a single save operation.
    public func insertBatch(systems: [System_Data]) throws {
        for system in systems { modelContext.insert(system) }
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: batch-inserted \(systems.count) system(s)")
    }

    /// Insert multiple save states in a single save operation.
    public func insertBatch(saveStates: [SaveState_Data]) throws {
        for saveState in saveStates { modelContext.insert(saveState) }
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: batch-inserted \(saveStates.count) save state(s)")
    }

    /// Insert multiple recent games in a single save operation.
    public func insertBatch(recentGames: [RecentGame_Data]) throws {
        for recentGame in recentGames { modelContext.insert(recentGame) }
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: batch-inserted \(recentGames.count) recent game(s)")
    }

    // MARK: Update

    /// Save any pending context changes.
    public func save() throws {
        try modelContext.save()
    }

    // MARK: Delete

    /// Delete a `Game_Data` record and save.
    public func delete(game: Game_Data) throws {
        modelContext.delete(game)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: deleted game \(game.id)")
    }

    /// Delete a `System_Data` record and save.
    public func delete(system: System_Data) throws {
        modelContext.delete(system)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: deleted system \(system.identifier)")
    }

    /// Delete a `SaveState_Data` record and save.
    public func delete(saveState: SaveState_Data) throws {
        modelContext.delete(saveState)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: deleted save state \(saveState.id)")
    }

    /// Delete a `RecentGame_Data` record and save.
    public func delete(recentGame: RecentGame_Data) throws {
        modelContext.delete(recentGame)
        try modelContext.save()
        DLOG("SwiftDataDatabaseDriver: deleted recent game \(recentGame.id)")
    }

    // MARK: Delete all

    /// Delete all objects of all tracked model types and save.
    ///
    /// Delegates to `PVSwiftDataSchema.deleteAll(from:)` so the type list stays in sync
    /// with the schema definition and is not duplicated here.
    public func deleteAll() throws {
        try PVSwiftDataSchema.deleteAll(from: modelContext)
        DLOG("SwiftDataDatabaseDriver: deleted all objects")
    }
}

// MARK: - SwiftDataDatabaseActor

/// Thread-safe async actor wrapping a `ModelContainer` for concurrent use.
///
/// Use this actor when you need to access the SwiftData store from background tasks
/// or concurrently from multiple callers. The API mirrors `SwiftDataDatabaseDriver`
/// with `async throws` signatures for actor-isolated access.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
@ModelActor
public actor SwiftDataDatabaseActor {

    // MARK: - Query

    /// Fetch a game by its MD5 hash identifier, matching the Realm driver semantics.
    /// - Parameter identifier: The game's `md5Hash` value.
    public func game(identifier: String) throws -> Game_Data? {
        var descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.md5Hash == identifier }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch a system by identifier.
    public func system(identifier: String) throws -> System_Data? {
        var descriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch all games, optionally sorted.
    public func allGames(sortedBy sortDescriptors: [SortDescriptor<Game_Data>] = []) throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all systems, optionally sorted.
    public func allSystems(sortedBy sortDescriptors: [SortDescriptor<System_Data>] = []) throws -> [System_Data] {
        let descriptor = FetchDescriptor<System_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all save states, optionally sorted.
    public func allSaveStates(sortedBy sortDescriptors: [SortDescriptor<SaveState_Data>] = []) throws -> [SaveState_Data] {
        let descriptor = FetchDescriptor<SaveState_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all recent games, optionally sorted.
    public func allRecentGames(sortedBy sortDescriptors: [SortDescriptor<RecentGame_Data>] = []) throws -> [RecentGame_Data] {
        let descriptor = FetchDescriptor<RecentGame_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch games matching a predicate.
    public func games(matching predicate: Predicate<Game_Data>,
                      sortedBy sortDescriptors: [SortDescriptor<Game_Data>] = []) throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(predicate: predicate, sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch games for a given system identifier.
    public func games(forSystemIdentifier systemIdentifier: String) throws -> [Game_Data] {
        try games(
            matching: #Predicate { $0.systemIdentifier == systemIdentifier },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Fetch favorite games sorted by title.
    public func favoriteGames() throws -> [Game_Data] {
        try games(
            matching: #Predicate { $0.isFavorite == true },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Search for games whose title contains `searchText` (case-insensitive).
    ///
    /// A store-side predicate using `contains` is applied first as a coarse filter,
    /// then an in-memory case-insensitive pass narrows the results.
    public func searchGames(for searchText: String) throws -> [Game_Data] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return try allGames(sortedBy: [SortDescriptor(\.title)]) }
        let coarse = try games(
            matching: #Predicate { game in game.title.contains(trimmed) },
            sortedBy: [SortDescriptor(\.title)]
        )
        let lower = trimmed.lowercased()
        return coarse.filter { $0.title.lowercased().contains(lower) }
    }

    // MARK: - Write

    /// Insert and persist a game record.
    public func insert(game: Game_Data) throws {
        modelContext.insert(game)
        try modelContext.save()
    }

    /// Insert and persist a system record.
    public func insert(system: System_Data) throws {
        modelContext.insert(system)
        try modelContext.save()
    }

    /// Insert and persist a save-state record.
    public func insert(saveState: SaveState_Data) throws {
        modelContext.insert(saveState)
        try modelContext.save()
    }

    /// Insert and persist a recent-game record.
    public func insert(recentGame: RecentGame_Data) throws {
        modelContext.insert(recentGame)
        try modelContext.save()
    }

    /// Persist any pending changes.
    public func save() throws {
        try modelContext.save()
    }

    // MARK: - Delete

    /// Delete a game record and persist.
    public func delete(game: Game_Data) throws {
        modelContext.delete(game)
        try modelContext.save()
    }

    /// Delete a system record and persist.
    public func delete(system: System_Data) throws {
        modelContext.delete(system)
        try modelContext.save()
    }

    /// Delete a save-state record and persist.
    public func delete(saveState: SaveState_Data) throws {
        modelContext.delete(saveState)
        try modelContext.save()
    }

    /// Delete a recent-game record and persist.
    public func delete(recentGame: RecentGame_Data) throws {
        modelContext.delete(recentGame)
        try modelContext.save()
    }

    /// Delete all objects of all tracked model types and persist.
    ///
    /// Delegates to `PVSwiftDataSchema.deleteAll(from:)` so the type list stays in sync
    /// with the schema definition and is not duplicated across driver and actor.
    public func deleteAll() throws {
        try PVSwiftDataSchema.deleteAll(from: modelContext)
    }
}
#endif
