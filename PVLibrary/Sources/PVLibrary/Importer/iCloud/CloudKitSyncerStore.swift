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
    
    /// Internal SyncerStore instance
    private let syncerStore = SyncerStore.shared
    
    /// Private initializer for singleton
    private init() {
        DLOG("CloudKitSyncerStore initialized")
    }
    
    /// Publisher for active syncers
    public var syncersPublisher: AnyPublisher<[SyncProvider], Never> {
        syncerStore.syncersPublisher
    }
    
    /// Get all active syncers
    public var activeSyncers: [SyncProvider] {
        syncerStore.activeSyncers
    }
    
    /// Register a syncer with the store
    /// - Parameter syncer: The syncer to register
    public func register(syncer: SyncProvider) {
        syncerStore.register(syncer: syncer)
    }
    
    /// Unregister a syncer from the store
    /// - Parameter syncer: The syncer to unregister
    public func unregister(syncer: SyncProvider) {
        syncerStore.unregister(syncer: syncer)
    }
    
    /// Clear all registered syncers
    public func clear() {
        syncerStore.clear()
    }
    
    /// Get syncers for specific directories
    /// - Parameter directories: The directories to filter by
    /// - Returns: Array of syncers that handle the specified directories
    public func syncers(for directories: Set<String>) -> [SyncProvider] {
        syncerStore.syncers(for: directories)
    }
    
    /// Get CloudKit-specific syncers
    public var cloudKitSyncers: [CloudKitSyncer] {
        activeSyncers.compactMap { $0 as? CloudKitSyncer }
    }
    
    /// Get all ROM syncers
    public var romSyncers: [RomsSyncing] {
        activeSyncers.compactMap { $0 as? RomsSyncing }
    }
    
    /// Get all save state syncers
    public var saveStateSyncers: [SaveStatesSyncing] {
        activeSyncers.compactMap { $0 as? SaveStatesSyncing }
    }
    
    /// Get all BIOS syncers
    public var biosSyncers: [BIOSSyncing] {
        activeSyncers.compactMap { $0 as? BIOSSyncing }
    }
}
#endif
