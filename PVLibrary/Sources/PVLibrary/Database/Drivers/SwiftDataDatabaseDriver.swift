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
import PVLogging

// MARK: - SwiftDataDatabaseDriver

/// Synchronous `DatabaseDriver` implementation backed by a SwiftData `ModelContext`.
///
/// `ModelContext` is not thread-safe; all accesses must occur on the thread on which
/// this driver was created. For concurrent or async use, prefer `SwiftDataDatabaseActor`,
/// which is a `@ModelActor` and enforces safe isolation at compile time.
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
    /// - Warning: `ModelContext` is not thread-safe. Access only from the thread this driver was created on.
    let modelContext: ModelContext

    // MARK: Init

    /// Designated initialiser. The `database` parameter is ignored — SwiftData manages
    /// its own container independently from Realm.
    public required init(database _: RomDatabase) {
        do {
            let container = try PVSwiftDataSchema.makePVModelContainer()
            self.modelContainer = container
            self.modelContext = ModelContext(container)
        } catch {
            ELOG("SwiftDataDatabaseDriver: failed to create persistent ModelContainer — \(error). Falling back to in-memory store.")
            // Avoid crashing; fall back to in-memory storage so the app remains usable.
            // Data will not be persisted across launches while in this degraded state.
            guard let fallback = try? PVSwiftDataSchema.makePVModelContainer(inMemory: true) else {
                fatalError("SwiftDataDatabaseDriver: unable to create even an in-memory ModelContainer")
            }
            self.modelContainer = fallback
            self.modelContext = ModelContext(fallback)
        }
    }

    /// Convenience initialiser for testing or standalone use.
    /// - Parameter inMemory: When `true`, data is stored only in memory (useful for tests).
    public init(inMemory: Bool = false) throws {
        let container = try PVSwiftDataSchema.makePVModelContainer(inMemory: inMemory)
        self.modelContainer = container
        self.modelContext = ModelContext(container)
    }

    // MARK: - DatabaseDriver protocol

    /// Fetch a game by its unique identifier (md5Hash, matching the Realm primary key).
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
extension SwiftDataDatabaseDriver {

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
            matching: #Predicate { $0.isFavorite },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Search for games whose title contains `searchText` (case-insensitive).
    public func searchGames(for searchText: String) throws -> [Game_Data] {
        if searchText.isEmpty {
            return try allGames(sortedBy: [SortDescriptor(\.title)])
        }
        return try games(
            matching: #Predicate { $0.title.localizedStandardContains(searchText) },
            sortedBy: [SortDescriptor(\.title)]
        )
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
    public func deleteAll() throws {
        try pvDeleteAllModels(from: modelContext)
        DLOG("SwiftDataDatabaseDriver: deleted all objects")
    }
}

// MARK: - Shared delete-all helper

/// Deletes all objects of every schema type from `context` and saves.
///
/// Centralised here so `SwiftDataDatabaseDriver` and `SwiftDataDatabaseActor`
/// stay in sync automatically as the schema evolves.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
private func pvDeleteAllModels(from context: ModelContext) throws {
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

// MARK: - SwiftDataDatabaseActor

/// Thread-safe async actor wrapping a `ModelContainer` for concurrent use.
///
/// Prefer this over `SwiftDataDatabaseDriver` whenever you need to access the SwiftData
/// store from background tasks or multiple concurrent callers. The `@ModelActor` macro
/// generates an isolated `ModelContext` that is guaranteed to be accessed serially,
/// eliminating data-race concerns without requiring `@MainActor` confinement.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
@ModelActor
public actor SwiftDataDatabaseActor {

    // MARK: - Query

    /// Fetch a game by identifier (md5Hash, matching the Realm primary key).
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
    public func allGames(sortedBy sortDescriptors: [SortDescriptor<Game_Data>] = [SortDescriptor(\.title)]) throws -> [Game_Data] {
        let descriptor = FetchDescriptor<Game_Data>(sortBy: sortDescriptors)
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all systems, optionally sorted.
    public func allSystems(sortedBy sortDescriptors: [SortDescriptor<System_Data>] = [SortDescriptor(\.name)]) throws -> [System_Data] {
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

    // MARK: - Filtered fetch

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
            matching: #Predicate { $0.isFavorite },
            sortedBy: [SortDescriptor(\.title)]
        )
    }

    /// Search for games whose title contains `searchText` (case-insensitive).
    public func searchGames(for searchText: String) throws -> [Game_Data] {
        if searchText.isEmpty {
            return try allGames(sortedBy: [SortDescriptor(\.title)])
        }
        return try games(
            matching: #Predicate { $0.title.localizedStandardContains(searchText) },
            sortedBy: [SortDescriptor(\.title)]
        )
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

    /// Delete all tracked objects and persist.
    public func deleteAll() throws {
        try pvDeleteAllModels(from: modelContext)
    }
}
#endif
