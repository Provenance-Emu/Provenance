//
//  PausableService.swift
//  PVPrimitives
//
//  Created on 2025-06-XX.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

/// Reasons for pausing or resuming a background service.
///
/// Services track a *set* of active reasons. Work only resumes once
/// every reason has been cleared, preventing one caller's resume from
/// undoing another caller's pause.
public enum ServiceLifecycleReason: String, Sendable, CaseIterable, Hashable {
    /// Active gameplay — conserve CPU/battery for the emulator
    case emulation
    /// App has entered the background
    case appBackgrounded
    /// User explicitly paused the service (e.g. via settings toggle)
    case userInitiated
    /// System resource pressure (thermal, memory, low-power mode)
    case systemResource
}

/// Protocol adopted by long-running background services that should
/// yield resources when the emulator (or other high-priority work) is active.
///
/// Each conformer maintains its own `activePauseReasons` set. The
/// `BackgroundServiceRegistry` iterates registered services so callers
/// need only a single `pauseAll(reason:)` / `resumeAll(reason:)` call.
public protocol PausableService: AnyObject {

    /// Human-readable identifier used in diagnostic logs
    var serviceName: String { get }

    /// The set of reasons currently keeping this service paused
    var activePauseReasons: Set<ServiceLifecycleReason> { get }

    /// Pause the service for the given reason.
    ///
    /// Implementations should add `reason` to `activePauseReasons`. If the
    /// service was previously running (set was empty), stop active work.
    /// If the reason was already present this should be a no-op.
    func pause(reason: ServiceLifecycleReason)

    /// Remove the given pause reason.
    ///
    /// Implementations should remove `reason` from `activePauseReasons`.
    /// Work should only resume when the set becomes empty. If the reason
    /// was not present this should be a no-op.
    func resume(reason: ServiceLifecycleReason)
}

// MARK: - Convenience

extension PausableService {
    /// Whether the service is currently paused for any reason
    public var isPaused: Bool { !activePauseReasons.isEmpty }

    /// Whether the service is paused for a specific reason
    public func isPaused(for reason: ServiceLifecycleReason) -> Bool {
        activePauseReasons.contains(reason)
    }
}
