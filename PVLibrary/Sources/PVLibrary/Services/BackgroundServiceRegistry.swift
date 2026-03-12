//
//  BackgroundServiceRegistry.swift
//  PVLibrary
//
//  Created on 2025-06-XX.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVPrimitives

/// Central registry for all long-running background services.
///
/// Callers use `pauseAll(reason:)` / `resumeAll(reason:)` instead of
/// reaching out to each service singleton. Services self-register via
/// `register(_:)` during their own initialisation.
///
/// Example:
/// ```swift
/// BackgroundServiceRegistry.shared.pauseAll(reason: .emulation)
/// ```
@MainActor
public final class BackgroundServiceRegistry {

    /// Shared singleton
    public static let shared = BackgroundServiceRegistry()

    // MARK: - Storage

    /// Weak boxes keyed by `ObjectIdentifier` to avoid duplicates and retain cycles
    private var entries: [ObjectIdentifier: WeakServiceBox] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a service for lifecycle management.
    /// Duplicate registrations for the same instance are ignored.
    public func register(_ service: any PausableService) {
        let id = ObjectIdentifier(service)
        guard entries[id] == nil else { return }
        entries[id] = WeakServiceBox(service)
        ILOG("BackgroundServiceRegistry: Registered '\(service.serviceName)' (\(liveCount) services)")
    }

    /// Remove a service from the registry
    public func unregister(_ service: any PausableService) {
        let id = ObjectIdentifier(service)
        entries.removeValue(forKey: id)
        ILOG("BackgroundServiceRegistry: Unregistered '\(service.serviceName)' (\(liveCount) services)")
    }

    // MARK: - Bulk Control

    /// Pause every registered service for the given reason
    public func pauseAll(reason: ServiceLifecycleReason) {
        pruneStale()
        let services = liveServices
        ILOG("BackgroundServiceRegistry: pauseAll(.\(reason.rawValue)) — \(services.count) services")
        for service in services {
            service.pause(reason: reason)
        }
    }

    /// Resume every registered service for the given reason.
    /// Each service only actually resumes once *all* its pause reasons are cleared.
    public func resumeAll(reason: ServiceLifecycleReason) {
        pruneStale()
        let services = liveServices
        ILOG("BackgroundServiceRegistry: resumeAll(.\(reason.rawValue)) — \(services.count) services")
        for service in services {
            service.resume(reason: reason)
        }
    }

    // MARK: - Queries

    /// Snapshot of all currently alive registered services
    public var registeredServices: [any PausableService] {
        pruneStale()
        return liveServices
    }

    /// Number of currently alive registrations
    public var liveCount: Int {
        entries.values.compactMap(\.service).count
    }

    /// Whether *any* registered service is paused for the given reason
    public func anyPaused(for reason: ServiceLifecycleReason) -> Bool {
        liveServices.contains { $0.isPaused(for: reason) }
    }

    // MARK: - Internals

    private var liveServices: [any PausableService] {
        entries.values.compactMap(\.service)
    }

    private func pruneStale() {
        entries = entries.filter { $0.value.service != nil }
    }
}

// MARK: - Weak Reference Box

private final class WeakServiceBox {
    weak var service: (any PausableService)?
    init(_ service: any PausableService) { self.service = service }
}
