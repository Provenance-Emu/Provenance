//
//  PVRetroArchCoreBridge+PVNetplayCapable.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVRetroArchCoreBridge to the PVNetplayCapable protocol so that
//  PVNetplayManager can drive RetroArch netplay sessions natively.
//
//  PVRetroArchCoreBridge+Netplay.h/.mm already implements the low-level
//  host/join/stop/flip via RetroArch's command_event() API.  This file
//  maps those calls to the protocol surface.
//

import Foundation
import ObjectiveC
import Combine
import PVNetplay

// MARK: - Sendable
//
// PVRetroArchCoreBridge is an Objective-C class whose netplay-state mutation
// occurs on RetroArch's internal run loop thread.  Marking it @unchecked
// Sendable is intentional — callers must not mutate netplay state concurrently.

extension PVRetroArchCoreBridge: @unchecked Sendable {}

// MARK: - Session context storage

/// Stores the last requested role and settings so `netplayState` can report
/// accurate host/port metadata rather than placeholder zeros.
private final class NetplaySessionContext {
    let role: NetplayRole
    let settings: NetplaySettings
    init(role: NetplayRole, settings: NetplaySettings) {
        self.role = role
        self.settings = settings
    }
}

private enum NetplayContextKey {
    /// Static storage used solely for its address as an associated-object key.
    static var sessionContextKey: UInt8 = 0
}

private extension PVRetroArchCoreBridge {
    var lastSessionContext: NetplaySessionContext? {
        get { objc_getAssociatedObject(self, &NetplayContextKey.sessionContextKey) as? NetplaySessionContext }
        // Use RETAIN (atomic) so cross-thread reads in netplayState are safe.
        set { objc_setAssociatedObject(self, &NetplayContextKey.sessionContextKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// MARK: - PVNetplayCapable

extension PVRetroArchCoreBridge: PVNetplayCapable {

    public var supportsNetplay: Bool { netplaySupported }

    public var netplayEngineName: String { "RetroArch" }

    // MARK: Control

    /// Start a netplay session with the given role and settings.
    ///
    /// Delegates to the Swift convenience wrappers on PVRetroArchCoreBridge
    /// defined in PVRetroArchCore+Netplay.swift.
    ///
    /// The underlying ObjC methods mutate RetroArch globals and must be called
    /// on the main thread (RetroArch's run loop is driven from the main queue
    /// in PVRetroArchCore).
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        let nickname: String? = settings.nickname.isEmpty ? nil : settings.nickname
        do {
            try await MainActor.run {
                // Store context inside MainActor.run so all reads/writes of
                // lastSessionContext are confined to the main executor — the same
                // thread that retroArchNetplayStatusPublisher polls on.
                lastSessionContext = NetplaySessionContext(role: role, settings: settings)
                switch role {
                case .host(let port):
                    try startNetplayHosting(
                        nickname: nickname,
                        port: port,
                        frameDelay: settings.frameDelay
                    )
                case .client(let host, let port):
                    try connectToNetplay(
                        host: host,
                        port: port,
                        nickname: nickname,
                        frameDelay: settings.frameDelay,
                        spectate: false
                    )
                case .spectator(let host, let port):
                    try connectToNetplay(
                        host: host,
                        port: port,
                        nickname: nickname,
                        frameDelay: settings.frameDelay,
                        spectate: true
                    )
                }
            }
        } catch {
            // Clear context on main executor to keep reads/writes serialised.
            await MainActor.run { lastSessionContext = nil }
            throw error
        }
    }

    /// Stop the current netplay session.
    ///
    /// The underlying ObjC method mutates RetroArch globals; dispatched on
    /// the main thread for thread safety.
    public func stopNetplay() async {
        // Both stopNetplaySession() and lastSessionContext clear run on the main
        // executor so they are serialised with the retroArchNetplayStatusPublisher.
        await MainActor.run {
            stopNetplaySession()
            lastSessionContext = nil
        }
    }

    // MARK: State

    /// Maps `PVRetroArchNetplayStatus` to the protocol-level `NetplayState`.
    ///
    /// Uses the stored session context (role + settings) to populate accurate
    /// host address, port, and frame-delay metadata when available.
    public var netplayState: NetplayState {
        netplayStatus.asNetplayState(context: lastSessionContext)
    }

    /// Publisher that emits `NetplayState` changes (polled once/second).
    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        retroArchNetplayStatusPublisher
            .map { [weak self] status in
                status.asNetplayState(context: self?.lastSessionContext)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - PVRetroArchNetplayStatus → NetplayState

private extension PVRetroArchNetplayStatus {
    /// Converts the raw RetroArch status enum to the protocol-level state.
    ///
    /// When `context` is provided the derived room/session is populated with
    /// the actual host address, port, and frame delay from the last
    /// `startNetplay(role:settings:)` call.  Without context a minimal
    /// placeholder is used (RetroArch does not expose full room metadata via
    /// its C status-query API at the poll level).
    func asNetplayState(context: NetplaySessionContext?) -> NetplayState {
        switch self {
        case .idle:
            return .idle
        case .hosting:
            let port: UInt16
            if case .host(let p) = context?.role { port = p } else { port = NetplaySettings.defaultLAN.port }
            let room = NetplayRoom.retroArchRoom(address: "0.0.0.0", port: port, context: context)
            return .hosting(room: room)
        case .connected:
            let (host, port) = context?.role.clientAddress ?? ("0.0.0.0", NetplaySettings.defaultLAN.port)
            let room = NetplayRoom.retroArchRoom(address: host, port: port, context: context)
            let session = NetplaySession(
                room: room,
                role: .client(host: host, port: port),
                peers: [],
                frameDelay: context?.settings.frameDelay ?? 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        case .spectating:
            let (host, port) = context?.role.clientAddress ?? ("0.0.0.0", NetplaySettings.defaultLAN.port)
            let room = NetplayRoom.retroArchRoom(address: host, port: port, context: context)
            let session = NetplaySession(
                room: room,
                role: .spectator(host: host, port: port),
                peers: [],
                frameDelay: context?.settings.frameDelay ?? 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        @unknown default:
            return .idle
        }
    }
}

// MARK: - NetplayRole helpers

private extension NetplayRole {
    /// Extracts (host, port) for client/spectator roles; returns nil for host role.
    var clientAddress: (String, UInt16)? {
        switch self {
        case .client(let host, let port): return (host, port)
        case .spectator(let host, let port): return (host, port)
        case .host: return nil
        }
    }
}

// MARK: - NetplayRoom factory

private extension NetplayRoom {
    /// Builds a room populated with as much context as is available.
    static func retroArchRoom(
        address: String,
        port: UInt16,
        context: NetplaySessionContext?
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }
        let isLAN = settings?.relayServer == nil
        let isPasswordProtected = !(settings?.password?.isEmpty ?? true)
        let allowsSpectators = settings?.allowSpectators ?? true
        return NetplayRoom(
            hostName: nickname ?? "RetroArch",
            gameName: "",
            gameHash: "",
            coreIdentifier: "com.provenance.retroarch",
            maxPlayers: settings?.maxPlayers ?? 2,
            currentPlayers: 1,
            isLAN: isLAN,
            hostAddress: address,
            port: port,
            discoverySource: .manual,
            isPasswordProtected: isPasswordProtected,
            allowsSpectators: allowsSpectators
        )
    }
}
