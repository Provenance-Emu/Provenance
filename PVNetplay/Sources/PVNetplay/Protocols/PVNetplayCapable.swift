//
//  PVNetplayCapable.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Protocol adopted by emulator cores that support netplay.
///
/// Implement this protocol on `PVEmulatorCore` subclasses (or their Swift wrappers)
/// to expose netplay controls to the `PVNetplayManager`.
///
/// - For RetroArch cores: implemented via `PVRetroArchCoreBridge+Netplay`
/// - For native cores (future): implemented directly on each core bridge
public protocol PVNetplayCapable: AnyObject, Sendable {
    /// Whether this core instance supports netplay.
    var supportsNetplay: Bool { get }

    /// A short human-readable name for the core's netplay engine (e.g. "RetroArch").
    var netplayEngineName: String { get }

    /// Start a netplay session with the given role and settings.
    /// - Throws: `NetplayError` on configuration or connection failure.
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws

    /// Stop the current netplay session.
    func stopNetplay() async

    /// The current netplay state.
    var netplayState: NetplayState { get }

    #if canImport(Combine)
    /// A publisher that emits state changes.
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> { get }
    #endif
}

// MARK: - NetplayError

/// Errors thrown by `PVNetplayCapable` implementations.
public enum NetplayError: Error, LocalizedError, Sendable {
    case unsupported
    case alreadyActive
    case connectionFailed(String)
    case romMismatch
    case sessionFull
    case invalidSettings(String)
    case bridgeNotReady
    case featureDisabled

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return "This core does not support netplay."
        case .alreadyActive:
            return "A netplay session is already active."
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .romMismatch:
            return "ROM mismatch — ensure both players have the same ROM."
        case .sessionFull:
            return "The room is full."
        case .invalidSettings(let reason):
            return "Invalid netplay settings: \(reason)"
        case .bridgeNotReady:
            return "The netplay bridge is not ready. Ensure the emulator is running."
        case .featureDisabled:
            return "Netplay is disabled. Enable it in Settings > Feature Flags."
        }
    }
}
