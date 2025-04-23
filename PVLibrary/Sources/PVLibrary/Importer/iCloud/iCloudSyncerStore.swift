//
//  iCloudSyncerStore.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/21/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import Combine

/// Manages access to active iCloud syncers for observation
public class iCloudSyncerStore {
    /// Shared instance
    public static let shared = iCloudSyncerStore()
    
    /// Active container syncers
    private var _activeSyncers: [iCloudContainerSyncer] = []
    
    /// Publisher for syncer changes
    private let syncersSubject = PassthroughSubject<[iCloudContainerSyncer], Never>()
    
    /// Publisher for active syncers
    public var syncersPublisher: AnyPublisher<[iCloudContainerSyncer], Never> {
        syncersSubject.eraseToAnyPublisher()
    }
    
    /// Get all active syncers
    public var activeSyncers: [iCloudContainerSyncer] {
        _activeSyncers
    }
    
    /// Private initializer for singleton
    private init() {}
    
    /// Register a syncer with the store
    /// - Parameter syncer: The syncer to register
    public func register(syncer: iCloudContainerSyncer) {
        // Only add if not already present
        if !_activeSyncers.contains(where: { $0 === syncer }) {
            _activeSyncers.append(syncer)
            syncersSubject.send(_activeSyncers)
            DLOG("Registered iCloud syncer: \(syncer)")
        }
    }
    
    /// Unregister a syncer from the store
    /// - Parameter syncer: The syncer to unregister
    public func unregister(syncer: iCloudContainerSyncer) {
        _activeSyncers.removeAll(where: { $0 === syncer })
        syncersSubject.send(_activeSyncers)
        DLOG("Unregistered iCloud syncer")
    }
    
    /// Clear all registered syncers
    public func clear() {
        _activeSyncers.removeAll()
        syncersSubject.send(_activeSyncers)
        DLOG("Cleared all iCloud syncers")
    }
    
    /// Get syncers for specific directories
    /// - Parameter directories: The directories to filter by
    /// - Returns: Array of syncers that handle the specified directories
    public func syncers(for directories: Set<String>) -> [iCloudContainerSyncer] {
        _activeSyncers.filter { !$0.directories.isDisjoint(with: directories) }
    }
    
    /// Get all ROM syncers
    /// - Returns: Array of ROM syncers
    public func romSyncers() -> [RomsSyncer] {
        _activeSyncers.compactMap { $0 as? RomsSyncer }
    }
}
