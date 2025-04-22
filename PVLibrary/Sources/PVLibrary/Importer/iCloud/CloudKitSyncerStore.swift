//
//  CloudKitSyncerStore.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import Combine

#if os(tvOS)
/// Manages access to active CloudKit syncers for observation
/// This is the tvOS equivalent of iCloudSyncerStore
public class CloudKitSyncerStore {
    /// Shared instance
    public static let shared = CloudKitSyncerStore()
    
    /// Active container syncers
    private var _activeSyncers: [CloudKitSyncer] = []
    
    /// Publisher for syncer changes
    private let syncersSubject = PassthroughSubject<[CloudKitSyncer], Never>()
    
    /// Publisher for active syncers
    public var syncersPublisher: AnyPublisher<[CloudKitSyncer], Never> {
        syncersSubject.eraseToAnyPublisher()
    }
    
    /// Get all active syncers
    public var activeSyncers: [CloudKitSyncer] {
        _activeSyncers
    }
    
    /// Private initializer for singleton
    private init() {}
    
    /// Register a syncer with the store
    /// - Parameter syncer: The syncer to register
    public func register(syncer: CloudKitSyncer) {
        // Only add if not already present
        if !_activeSyncers.contains(where: { $0 === syncer }) {
            _activeSyncers.append(syncer)
            syncersSubject.send(_activeSyncers)
            DLOG("Registered CloudKit syncer: \(syncer)")
        }
    }
    
    /// Unregister a syncer from the store
    /// - Parameter syncer: The syncer to unregister
    public func unregister(syncer: CloudKitSyncer) {
        _activeSyncers.removeAll(where: { $0 === syncer })
        syncersSubject.send(_activeSyncers)
        DLOG("Unregistered CloudKit syncer")
    }
    
    /// Clear all registered syncers
    public func clear() {
        _activeSyncers.removeAll()
        syncersSubject.send(_activeSyncers)
        DLOG("Cleared all CloudKit syncers")
    }
    
    /// Get syncers for specific directories
    /// - Parameter directories: The directories to filter by
    /// - Returns: Array of syncers that handle the specified directories
    public func syncers(for directories: Set<String>) -> [CloudKitSyncer] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: directories) }
    }
    
    /// Get all ROM syncers
    /// - Returns: Array of ROM syncers
    public func romSyncers() -> [RomsSyncing] {
        _activeSyncers.compactMap { $0 as? RomsSyncing }
    }
}
#endif
