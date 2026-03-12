//
//  DirectoryWatcherService.swift
//  PVLibrary
//
//  Created on 2025-06-XX.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVPrimitives

/// `@MainActor` bridge that adapts the actor-based `DirectoryWatcherRegistry`
/// to the `PausableService` protocol so it can participate in
/// `BackgroundServiceRegistry` bulk pause/resume.
@MainActor
public final class DirectoryWatcherService: PausableService {

    /// Shared singleton
    public static let shared = DirectoryWatcherService()

    public let serviceName = "DirectoryWatchers"

    public private(set) var activePauseReasons = Set<ServiceLifecycleReason>()

    private init() {
        BackgroundServiceRegistry.shared.register(self)
    }

    // MARK: - PausableService

    public func pause(reason: ServiceLifecycleReason) {
        guard !activePauseReasons.contains(reason) else { return }
        activePauseReasons.insert(reason)
        if activePauseReasons.count == 1 {
            ILOG("DirectoryWatcherService: Pausing watchers (reason: \(reason.rawValue))")
            Task { await DirectoryWatcherRegistry.pauseAll() }
        }
    }

    public func resume(reason: ServiceLifecycleReason) {
        guard activePauseReasons.contains(reason) else { return }
        activePauseReasons.remove(reason)
        if activePauseReasons.isEmpty {
            ILOG("DirectoryWatcherService: Resuming watchers (reason: \(reason.rawValue))")
            Task { await DirectoryWatcherRegistry.resumeAll() }
        }
    }
}
