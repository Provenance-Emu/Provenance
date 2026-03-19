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
import Combine
import PVNetplay

// MARK: - Sendable
//
// PVRetroArchCoreBridge is an Objective-C class whose netplay-state mutation
// occurs on RetroArch's internal run loop thread.  Marking it @unchecked
// Sendable is intentional — callers must not mutate netplay state concurrently.

extension PVRetroArchCoreBridge: @unchecked Sendable {}

// MARK: - PVNetplayCapable

extension PVRetroArchCoreBridge: PVNetplayCapable {

    public var supportsNetplay: Bool { true }

    public var netplayEngineName: String { "RetroArch" }

    // MARK: Control

    /// Start a netplay session with the given role and settings.
    ///
    /// Delegates to the Swift convenience wrappers on PVRetroArchCoreBridge
    /// defined in PVRetroArchCore+Netplay.swift.
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        let nickname: String? = settings.nickname.isEmpty ? nil : settings.nickname
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

    /// Stop the current netplay session.
    public func stopNetplay() async {
        stopNetplaySession()
    }

    // MARK: State

    /// Maps `PVRetroArchNetplayStatus` to the protocol-level `NetplayState`.
    public var netplayState: NetplayState {
        netplayStatus.asNetplayState
    }

    /// Publisher that emits `NetplayState` changes (polled once/second).
    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        retroArchNetplayStatusPublisher
            .map { $0.asNetplayState }
            .eraseToAnyPublisher()
    }
}

// MARK: - PVRetroArchNetplayStatus → NetplayState

private extension PVRetroArchNetplayStatus {
    /// Converts the raw RetroArch status enum to the protocol-level state.
    ///
    /// For hosting/connected states a minimal placeholder `NetplayRoom` is
    /// created because RetroArch does not expose the full room metadata via
    /// its C API at the status-query level.
    var asNetplayState: NetplayState {
        switch self {
        case .idle:
            return .idle
        case .hosting:
            return .hosting(room: .retroArchPlaceholder(address: "0.0.0.0"))
        case .connected:
            let room = NetplayRoom.retroArchPlaceholder(address: "0.0.0.0")
            let session = NetplaySession(
                room: room,
                role: .client(host: "0.0.0.0", port: 55435),
                peers: [],
                frameDelay: 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        case .spectating:
            let room = NetplayRoom.retroArchPlaceholder(address: "0.0.0.0")
            let session = NetplaySession(
                room: room,
                role: .spectator(host: "0.0.0.0", port: 55435),
                peers: [],
                frameDelay: 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        @unknown default:
            return .idle
        }
    }
}

// MARK: - NetplayRoom placeholder

private extension NetplayRoom {
    /// A minimal stand-in room used when RetroArch is active but detailed
    /// room metadata is unavailable through the C status API.
    static func retroArchPlaceholder(address: String, port: UInt16 = 55435) -> NetplayRoom {
        NetplayRoom(
            hostName: "RetroArch",
            gameName: "",
            gameHash: "",
            coreIdentifier: "com.provenance.retroarch",
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: address,
            port: port,
            discoverySource: .manual
        )
    }
}
