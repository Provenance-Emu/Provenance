//
//  ArtworkSearchQueueLifecycleBridge.swift
//  PVLibrary
//
//  Bridges `ArtworkSearchQueue` to `BackgroundServiceRegistry` so bulk artwork
//  work pauses during emulation and other high-priority sessions.
//

import Foundation
import PVLogging
import PVPrimitives

/// `@MainActor` lifecycle adapter for the `ArtworkSearchQueue` actor.
@MainActor
public final class ArtworkSearchQueueLifecycleBridge: PausableService {

    public static let shared = ArtworkSearchQueueLifecycleBridge()

    public let serviceName = "ArtworkSearchQueue"
    public private(set) var activePauseReasons = Set<ServiceLifecycleReason>()

    private var didRegister = false

    private init() {}

    /// Registers with `BackgroundServiceRegistry` once (safe to call repeatedly).
    public func ensureRegistered() {
        guard !didRegister else { return }
        didRegister = true
        BackgroundServiceRegistry.shared.register(self)
        ILOG("ArtworkSearchQueueLifecycleBridge: Registered with BackgroundServiceRegistry")
    }

    public func pause(reason: ServiceLifecycleReason) {
        let wasPaused = !activePauseReasons.isEmpty
        activePauseReasons.insert(reason)
        guard !wasPaused else { return }
        Task { await ArtworkSearchQueue.shared.setPaused(true) }
    }

    public func resume(reason: ServiceLifecycleReason) {
        activePauseReasons.remove(reason)
        guard activePauseReasons.isEmpty else { return }
        Task { await ArtworkSearchQueue.shared.setPaused(false) }
    }
}
