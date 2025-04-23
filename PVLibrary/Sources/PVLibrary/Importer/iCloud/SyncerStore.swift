//
//  SyncerStore.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import Combine

/// Manages access to active sync providers for observation
/// Platform-agnostic store that works on both iOS and tvOS
public class SyncerStore {
    /// Shared instance
    public static let shared = SyncerStore()
    
    /// Active sync providers
    private var _activeSyncers: [SyncProvider] = []
    
    /// Publisher for syncer changes
    private let syncersSubject = PassthroughSubject<[SyncProvider], Never>()
    
    /// Publisher for active syncers
    public var syncersPublisher: AnyPublisher<[SyncProvider], Never> {
        syncersSubject.eraseToAnyPublisher()
    }
    
    /// Get all active syncers
    public var activeSyncers: [SyncProvider] {
        _activeSyncers
    }
    
    /// Private initializer for singleton
    private init() {}
    
    /// Register a syncer with the store
    /// - Parameter syncer: The syncer to register
    public func register(syncer: SyncProvider) {
        // Only add if not already present
        if !_activeSyncers.contains(where: { $0 === syncer }) {
            _activeSyncers.append(syncer)
            syncersSubject.send(_activeSyncers)
            DLOG("Registered sync provider: \(syncer)")
        }
    }
    
    /// Unregister a syncer from the store
    /// - Parameter syncer: The syncer to unregister
    public func unregister(syncer: SyncProvider) {
        _activeSyncers.removeAll(where: { $0 === syncer })
        syncersSubject.send(_activeSyncers)
        DLOG("Unregistered sync provider")
    }
    
    /// Clear all registered syncers
    public func clear() {
        _activeSyncers.removeAll()
        syncersSubject.send(_activeSyncers)
        DLOG("Cleared all sync providers")
    }
    
    /// Get syncers for specific directories
    /// - Parameter directories: The directories to filter by
    /// - Returns: Array of syncers that handle the specified directories
    public func syncers(for directories: Set<String>) -> [SyncProvider] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: directories) }
    }
    
    /// Get all ROM syncers
    public var romSyncers: [SyncProvider] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: ["ROMs"]) }
    }
    
    /// Get all save state syncers
    public var saveStateSyncers: [SyncProvider] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: ["Save States"]) }
    }
    
    /// Get all BIOS syncers
    public var biosSyncers: [SyncProvider] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: ["BIOS"]) }
    }
}
