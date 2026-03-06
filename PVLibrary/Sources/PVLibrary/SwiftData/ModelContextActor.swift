//
//  ModelContextActor.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Provides thread-safe SwiftData model access patterns, mirroring the
//  `RealmContext` / `RealmActor` helpers used in the Realm-based sync layer.
//
//  Usage:
//    // Fetch a game by MD5 in a background context:
//    let game = try await ModelContextActor.shared.perform { ctx in
//        let descriptor = FetchDescriptor<Game_Data>(
//            predicate: #Predicate { $0.md5Hash == md5 }
//        )
//        return try ctx.fetch(descriptor).first
//    }
//
//    // Insert/update from any isolation domain:
//    try await ModelContextActor.shared.perform { ctx in
//        ctx.insert(newGame)
//        try ctx.save()
//    }

#if canImport(SwiftData)
import SwiftData
import Foundation

/// A global actor that serialises access to a background `ModelContext`,
/// providing the same "safe DB access from any thread" ergonomics that
/// `RealmContext.withBackgroundRealm` offers for Realm.
///
/// The container used by this actor is set once at app start-up via
/// `ModelContextActor.configure(container:)`.  Until configured the actor
/// uses an in-memory fallback so that unit tests work without extra setup.
@globalActor
public actor ModelContextActor: GlobalActor {

    // MARK: - Shared instance

    public static let shared = ModelContextActor()

    // MARK: - Internal state

    private var _container: ModelContainer?
    private var _context: ModelContext?

    // MARK: - Configuration

    /// Call once at app start-up (e.g. in `@main` body or `AppDelegate`) to
    /// inject the real `ModelContainer`.  Subsequent calls replace the container
    /// and invalidate the cached context.
    public func configure(container: ModelContainer) {
        _container = container
        _context = nil // lazily recreated on next access
    }

    // MARK: - Context access

    /// Returns the cached background `ModelContext`, creating it on first access.
    private func context() throws -> ModelContext {
        if let ctx = _context { return ctx }

        let container: ModelContainer
        if let c = _container {
            container = c
        } else {
            // Fallback: in-memory container for unit tests / previews.
            // In production this path indicates that configure(container:) was never called,
            // which means SwiftData changes will NOT be persisted. This is intentional for
            // previews and unit tests; production code must call configure(container:) at startup.
            assertionFailure("ModelContextActor.context() called before configure(container:) — no data will be persisted. Call configure(container:) at app startup.")
            container = try PVSwiftDataSchema.makePVModelContainer(inMemory: true)
            _container = container
        }

        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        _context = ctx
        return ctx
    }

    // MARK: - Perform helpers

    /// Runs `operation` inside the actor's serialised context.
    ///
    /// The closure receives the background `ModelContext` and may freely fetch,
    /// insert, delete, and save models.  Any thrown error propagates to the caller.
    ///
    /// The closure is required to be `@Sendable` so that callers cannot accidentally
    /// capture non-sendable state across the actor boundary.
    @discardableResult
    public func perform<T: Sendable>(
        _ operation: @Sendable (ModelContext) throws -> T
    ) async throws -> T {
        let ctx = try context()
        return try operation(ctx)
    }

    /// Convenience: perform a read-only fetch without calling `save()`.
    ///
    /// Accesses the actor's context directly rather than routing through
    /// `perform(_:)`, which requires the return type to be `Sendable`.
    /// `@Model` reference types do not conform to `Sendable`, so this
    /// approach avoids the constraint while remaining actor-isolated.
    public func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) async throws -> [T] {
        let ctx = try context()
        return try ctx.fetch(descriptor)
    }
}

// MARK: - Convenience extensions

public extension ModelContextActor {
    /// Fetch a single `Game_Data` by its MD5 hash.
    func fetchGame(md5: String) async throws -> Game_Data? {
        let upperMD5 = md5.uppercased()
        return try await fetch(
            FetchDescriptor<Game_Data>(predicate: #Predicate { $0.md5Hash == upperMD5 })
        ).first
    }

    /// Fetch all `SaveState_Data` records for a given game ID.
    ///
    /// Optional-chaining inside `#Predicate` (`game?.id`) is not reliably supported
    /// by SwiftData's predicate compiler, so we fetch all save states and filter
    /// by game ID in memory — consistent with `SwiftDataSyncActor.fetchSaveStatesNeedingUpload`.
    func fetchSaveStates(gameID: String) async throws -> [SaveState_Data] {
        let all = try await fetch(FetchDescriptor<SaveState_Data>())
        return all.filter { $0.game?.id == gameID }
    }

    /// Fetch a `BIOS_Data` record by its expected MD5 hash.
    func fetchBIOS(md5: String) async throws -> BIOS_Data? {
        let upperMD5 = md5.uppercased()
        return try await fetch(
            FetchDescriptor<BIOS_Data>(predicate: #Predicate { $0.expectedMD5 == upperMD5 })
        ).first
    }

    /// Insert a model and save the context in a single operation.
    func insertAndSave<T: PersistentModel>(_ model: T) async throws {
        try await perform { ctx in
            ctx.insert(model)
            try ctx.save()
        }
    }

    /// Delete a model and save the context in a single operation.
    func deleteAndSave<T: PersistentModel>(_ model: T) async throws {
        try await perform { ctx in
            ctx.delete(model)
            try ctx.save()
        }
    }
}
#endif
