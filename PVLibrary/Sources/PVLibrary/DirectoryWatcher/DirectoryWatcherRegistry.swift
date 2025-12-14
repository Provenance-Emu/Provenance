//
//  DirectoryWatcherRegistry.swift
//  PVLibrary
//
//  Created on 2025-01-XX.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Registry for tracking and controlling DirectoryWatcher instances
/// Provides direct pause/resume control instead of using notifications
public actor DirectoryWatcherRegistry {
    /// Shared singleton instance
    public static let shared = DirectoryWatcherRegistry()

    /// Weak references to avoid retain cycles
    private var watchers: [WeakWatcherRef] = []

    private init() {
        ILOG("DirectoryWatcherRegistry initialized")
    }

    /// Register a DirectoryWatcher instance
    public func register(_ watcher: DirectoryWatcher) {
        /// Remove any stale weak references
        watchers.removeAll { $0.watcher == nil }

        /// Check if already registered
        if watchers.contains(where: { $0.watcher === watcher }) {
            DLOG("DirectoryWatcher already registered")
            return
        }

        watchers.append(WeakWatcherRef(watcher: watcher))
        ILOG("DirectoryWatcher registered. Total watchers: \(watchers.count)")
    }

    /// Unregister a DirectoryWatcher instance
    public func unregister(_ watcher: DirectoryWatcher) {
        watchers.removeAll { $0.watcher === watcher }
        ILOG("DirectoryWatcher unregistered. Total watchers: \(watchers.count)")
    }

    /// Pause all registered watchers
    public func pauseAll() {
        /// Remove stale references
        watchers.removeAll { $0.watcher == nil }

        ILOG("Pausing \(watchers.count) DirectoryWatcher instances")
        for ref in watchers {
            ref.watcher?.pauseForEmulation()
        }
    }

    /// Resume all registered watchers
    public func resumeAll() {
        /// Remove stale references
        watchers.removeAll { $0.watcher == nil }

        ILOG("Resuming \(watchers.count) DirectoryWatcher instances")
        for ref in watchers {
            ref.watcher?.resumeFromEmulation()
        }
    }

    /// Get count of registered watchers
    public var count: Int {
        watchers.removeAll { $0.watcher == nil }
        return watchers.count
    }

    // MARK: - Static Convenience Methods

    /// Pause all registered watchers (static convenience method)
    public static func pauseAll() async {
        await shared.pauseAll()
    }

    /// Resume all registered watchers (static convenience method)
    public static func resumeAll() async {
        await shared.resumeAll()
    }

    /// Register a DirectoryWatcher instance (static convenience method)
    public static func register(_ watcher: DirectoryWatcher) async {
        await shared.register(watcher)
    }

    /// Unregister a DirectoryWatcher instance (static convenience method)
    public static func unregister(_ watcher: DirectoryWatcher) async {
        await shared.unregister(watcher)
    }
}

/// Weak reference wrapper for DirectoryWatcher
private class WeakWatcherRef {
    weak var watcher: DirectoryWatcher?

    init(watcher: DirectoryWatcher) {
        self.watcher = watcher
    }
}
