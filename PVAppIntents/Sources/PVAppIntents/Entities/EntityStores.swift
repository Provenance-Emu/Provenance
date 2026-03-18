//
//  EntityStores.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  EntityStore types act as lightweight in-process caches backing AppEntity
//  queries. The host app populates them via update(all:) after any library
//  change. Queries read directly from the in-memory dictionaries, keeping
//  AppIntents lookups fast without blocking on Realm I/O.

import Foundation

#if canImport(AppIntents)

// MARK: - GameEntityStore

/// Thread-safe in-process cache of `GameEntity` values.
/// The host app updates this store; AppEntity queries read from it.
public final class GameEntityStore: @unchecked Sendable {
    public static let shared = GameEntityStore()

    private let lock = NSLock()
    private var byID: [String: GameEntity] = [:]
    private var recentsOrdered: [GameEntity] = []

    private init() {}

    /// Replace the entire cache with a new set of entities.
    /// Call this from the main app whenever the library changes.
    public func update(all entities: [GameEntity], recents: [GameEntity]) {
        lock.lock()
        defer { lock.unlock() }
        byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        recentsOrdered = recents
    }

    public func entity(for id: String) -> GameEntity? {
        lock.lock()
        defer { lock.unlock() }
        return byID[id]
    }

    public func recentEntities(limit: Int) -> [GameEntity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(recentsOrdered.prefix(limit))
    }

    public func allEntities() -> [GameEntity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(byID.values)
    }
}

// MARK: - SystemEntityStore

public final class SystemEntityStore: @unchecked Sendable {
    public static let shared = SystemEntityStore()

    private let lock = NSLock()
    private var byID: [String: SystemEntity] = [:]

    private init() {}

    public func update(all entities: [SystemEntity]) {
        lock.lock()
        defer { lock.unlock() }
        byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
    }

    public func entity(for id: String) -> SystemEntity? {
        lock.lock()
        defer { lock.unlock() }
        return byID[id]
    }

    public func allEntities() -> [SystemEntity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(byID.values).sorted { $0.name < $1.name }
    }
}

// MARK: - SaveStateEntityStore

public final class SaveStateEntityStore: @unchecked Sendable {
    public static let shared = SaveStateEntityStore()

    private let lock = NSLock()
    private var byID: [String: SaveStateEntity] = [:]
    private var recentsOrdered: [SaveStateEntity] = []

    private init() {}

    public func update(all entities: [SaveStateEntity], recents: [SaveStateEntity]) {
        lock.lock()
        defer { lock.unlock() }
        byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        recentsOrdered = recents
    }

    public func entity(for id: String) -> SaveStateEntity? {
        lock.lock()
        defer { lock.unlock() }
        return byID[id]
    }

    public func recentEntities(limit: Int) -> [SaveStateEntity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(recentsOrdered.prefix(limit))
    }
}

#endif
