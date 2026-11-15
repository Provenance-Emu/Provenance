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
//
//  Each store keeps its values inside the lock that guards them, so no read or
//  write can reach them without holding it.

import Foundation

#if canImport(AppIntents)
import os

// MARK: - GameEntityStore

/// Thread-safe in-process cache of `GameEntity` values.
/// The host app updates this store; AppEntity queries read from it.
public final class GameEntityStore: Sendable {
    public static let shared = GameEntityStore()

    private struct State: Sendable {
        var byID: [String: GameEntity] = [:]
        var recentsOrdered: [GameEntity] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    private init() {}

    /// Replace the entire cache with a new set of entities.
    /// Call this from the main app whenever the library changes.
    public func update(all entities: [GameEntity], recents: [GameEntity]) {
        // Built before the lock is taken: readers wait only for the swap.
        let replacement = State(byID: Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) }),
                                recentsOrdered: recents)
        state.withLock { $0 = replacement }
    }

    public func entity(for id: String) -> GameEntity? {
        state.withLock { $0.byID[id] }
    }

    public func recentEntities(limit: Int) -> [GameEntity] {
        state.withLock { Array($0.recentsOrdered.prefix(limit)) }
    }

    public func allEntities() -> [GameEntity] {
        state.withLock { Array($0.byID.values) }
    }
}

// MARK: - SystemEntityStore

public final class SystemEntityStore: Sendable {
    public static let shared = SystemEntityStore()

    private let byID = OSAllocatedUnfairLock(initialState: [String: SystemEntity]())

    private init() {}

    public func update(all entities: [SystemEntity]) {
        let replacement = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        byID.withLock { $0 = replacement }
    }

    public func entity(for id: String) -> SystemEntity? {
        byID.withLock { $0[id] }
    }

    public func allEntities() -> [SystemEntity] {
        // Sorted after the lock is released.
        byID.withLock { Array($0.values) }.sorted { $0.name < $1.name }
    }
}

// MARK: - SaveStateEntityStore

public final class SaveStateEntityStore: Sendable {
    public static let shared = SaveStateEntityStore()

    private struct State: Sendable {
        var byID: [String: SaveStateEntity] = [:]
        var recentsOrdered: [SaveStateEntity] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    private init() {}

    public func update(all entities: [SaveStateEntity], recents: [SaveStateEntity]) {
        let replacement = State(byID: Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) }),
                                recentsOrdered: recents)
        state.withLock { $0 = replacement }
    }

    public func entity(for id: String) -> SaveStateEntity? {
        state.withLock { $0.byID[id] }
    }

    public func recentEntities(limit: Int) -> [SaveStateEntity] {
        state.withLock { Array($0.recentsOrdered.prefix(limit)) }
    }
}

#endif
