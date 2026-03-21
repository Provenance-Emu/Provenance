//
//  MednafenGameCore+PVNetplayCapable.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts MednafenGameCoreBridge to the PVNetplayCapable protocol so that
//  PVNetplayManager can drive Mednafen netplay sessions natively.
//
//  Mednafen netplay model:
//    - Requires a running `mednafen-server` TCP server (default port 4046).
//    - All players connect *as clients* to the server — there is no peer-to-peer
//      host/client distinction at the C++ level.
//    - "Hosting" in Provenance maps to connecting to 127.0.0.1 (local server).
//    - "Joining" maps to connecting to the host's LAN/WAN IP.
//    - Spectators: Mednafen does not have a native spectator mode; spectate
//      falls back to joining as a regular client on player slot 0.
//

import Foundation
import Combine
import PVNetplay
import MednafenGameCoreBridge

// MARK: - Sendable
//
// MednafenGameCoreBridge is ObjC; its netplay state is mutated by Mednafen's
// run-loop thread. @unchecked Sendable is intentional here — callers must not
// mutate netplay state concurrently.
extension MednafenGameCoreBridge: @unchecked Sendable {}

// MARK: - PVNetplayCapable

extension MednafenGameCoreBridge: PVNetplayCapable {

    public var supportsNetplay: Bool { mednafenNetplaySupported }

    public var netplayEngineName: String { "Mednafen" }

    // MARK: Control

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard mednafenNetplaySupported else { throw NetplayError.unsupported }
        guard mednafenNetplayStatus == .idle else { throw NetplayError.alreadyActive }

        let (host, port) = resolvedHostPort(for: role, settings: settings)
        let password = settings.password ?? ""

        var nsError: NSError?
        let ok = netplayConnectToHost(host,
                                      port: port,
                                      nickname: settings.nickname,
                                      password: password,
                                      error: &nsError)
        if !ok {
            let desc = nsError?.localizedDescription ?? "Mednafen connection failed."
            throw NetplayError.connectionFailed(desc)
        }
    }

    public func stopNetplay() async {
        netplayDisconnect()
    }

    // MARK: State

    public var netplayState: NetplayState {
        switch mednafenNetplayStatus {
        case .idle:
            return .idle
        case .connected:
            let room = NetplayRoom(
                hostName: "Mednafen",
                gameName: "",
                gameHash: "",
                coreIdentifier: "com.provenance.mednafen",
                maxPlayers: 2,
                currentPlayers: 2,
                isLAN: true,
                hostAddress: "0.0.0.0",
                port: 4046
            )
            let session = NetplaySession(
                room: room,
                role: .client(host: "0.0.0.0", port: 4046),
                peers: [],
                frameDelay: 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        @unknown default:
            return .idle
        }
    }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        // Poll every second — Mednafen does not expose a Combine-ready status publisher.
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { [weak self] _ in self?.netplayState ?? .idle }
            .eraseToAnyPublisher()
    }

    // MARK: - Helpers

    /// Resolves (host, port) from a `NetplayRole`.
    ///
    /// For `.host`: returns `("127.0.0.1", settings.port)` — the caller is expected
    /// to have already started a local `mednafen-server` on that port.
    private func resolvedHostPort(for role: NetplayRole,
                                  settings: NetplaySettings) -> (String, UInt16) {
        switch role {
        case .host(let port):
            // "Hosting" = connect to local server.
            return ("127.0.0.1", port)
        case .client(let host, let port):
            return (host, port)
        case .spectator(let host, let port):
            // Mednafen has no spectator role — join as client.
            return (host, port)
        }
    }
}
