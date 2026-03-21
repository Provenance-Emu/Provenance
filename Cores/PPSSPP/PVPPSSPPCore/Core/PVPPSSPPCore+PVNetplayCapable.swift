//
//  PVPPSSPPCore+PVNetplayCapable.swift
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVPPSSPPCore to the PVNetplayCapable protocol so that
//  PVNetplayManager can drive PPSSPP Ad Hoc sessions.
//
//  PPSSPP adhoc model:
//   - All players point at the same PRO Adhoc Server address.
//   - host(port:)      → run local adhoc server; proAdhocServer = "127.0.0.1"
//   - client(host:)    → proAdhocServer = host's LAN IP
//   - spectator(host:) → same as client (PPSSPP has no spectator concept)
//   - port parameter is unused — PPSSPP's adhoc server uses a fixed UDP port.
//

import Foundation
import Combine
import PVNetplay
import ObjectiveC

// MARK: - Session context storage

private final class PPSSPPNetplayContext {
    let role: NetplayRole
    let settings: NetplaySettings
    /// Stable IDs for the lifetime of this session so NetplayState equality
    /// checks (via UUID comparison) remain stable between timer ticks.
    let roomID: UUID
    let sessionID: UUID
    /// The effective adhoc server address used to start/join this session.
    /// For LAN hosts this is "127.0.0.1"; for WAN hosts or clients this is
    /// the relay/host address passed to connectToAdhocServer.
    let effectiveServerAddress: String
    init(role: NetplayRole, settings: NetplaySettings, effectiveServerAddress: String) {
        self.role = role
        self.settings = settings
        self.roomID = UUID()
        self.sessionID = UUID()
        self.effectiveServerAddress = effectiveServerAddress
    }
}

private enum PPSSPPNetplayContextKey {
    static var sessionContextKey: UInt8 = 0
}

private extension PVPPSSPPCore {
    var lastNetplayContext: PPSSPPNetplayContext? {
        get { objc_getAssociatedObject(self, &PPSSPPNetplayContextKey.sessionContextKey) as? PPSSPPNetplayContext }
        set { objc_setAssociatedObject(self, &PPSSPPNetplayContextKey.sessionContextKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// MARK: - Publisher storage

private enum PPSSPPStatePublisherKey {
    static var key: UInt8 = 0
}

private extension PVPPSSPPCore {
    /// A timer-driven publisher that polls adhoc status once per second.
    var adhocStatePublisher: AnyPublisher<NetplayState, Never> {
        if let existing = objc_getAssociatedObject(self, &PPSSPPStatePublisherKey.key) as? AnyPublisher<NetplayState, Never> {
            return existing
        }
        // .share() ensures a single upstream timer drives all subscribers instead
        // of each subscriber creating its own 1-second polling loop.
        let pub = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { [weak self] _ -> NetplayState in
                guard let self else { return .idle }
                return self.currentNetplayState
            }
            .removeDuplicates()
            .share()
            .eraseToAnyPublisher()
        objc_setAssociatedObject(self, &PPSSPPStatePublisherKey.key, pub, .OBJC_ASSOCIATION_RETAIN)
        return pub
    }

    var currentNetplayState: NetplayState {
        let status = _bridge.adhocStatus
        switch status {
        case .idle:
            return .idle
        case .hosting:
            let ctx = lastNetplayContext
            let settings = ctx?.settings
            let port: UInt16 = settings?.port ?? NetplaySettings.defaultLAN.port
            let room = NetplayRoom.ppssppRoom(id: ctx?.roomID ?? UUID(), address: "127.0.0.1", port: port, context: ctx)
            return .hosting(room: room)
        case .connected:
            let ctx = lastNetplayContext
            // Use the stored effective address (relay or peer IP) rather than
            // role.clientAddress, which is nil for hosts using a relay server.
            let host = ctx?.effectiveServerAddress ?? "0.0.0.0"
            let port: UInt16 = ctx?.role.clientAddress?.1 ?? ctx?.settings.port ?? NetplaySettings.defaultLAN.port
            let room = NetplayRoom.ppssppRoom(id: ctx?.roomID ?? UUID(), address: host, port: port, context: ctx)
            let session = NetplaySession(
                id: ctx?.sessionID ?? UUID(),
                room: room,
                role: .client(host: host, port: port),
                peers: [],
                frameDelay: ctx?.settings.frameDelay ?? 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        @unknown default:
            return .idle
        }
    }
}

// MARK: - PVNetplayCapable

extension PVPPSSPPCore: PVNetplayCapable {

    public var supportsNetplay: Bool { true }

    public var netplayEngineName: String { "PPSSPP AdHoc" }

    // MARK: Control

    /// Start a PPSSPP adhoc session.
    ///
    /// All mutations of g_Config must occur on the main thread (where the
    /// PPSSPP run loop executes).
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        try await MainActor.run {
            var error: NSError?
            let ok: Bool
            let effectiveAddress: String
            switch role {
            case .host:
                if let relay = settings.relayServer {
                    // WAN mode: connect to external relay server rather than hosting locally.
                    effectiveAddress = relay
                    ok = _bridge.connectToAdhocServer(relay, error: &error)
                } else {
                    effectiveAddress = "127.0.0.1"
                    ok = _bridge.startAdhocLANHost(error: &error)
                }
            case .client(let host, _):
                effectiveAddress = host
                ok = _bridge.connectToAdhocServer(host, error: &error)
            case .spectator(let host, _):
                // PPSSPP has no spectator concept — join as a regular client.
                effectiveAddress = host
                ok = _bridge.connectToAdhocServer(host, error: &error)
            }
            if !ok {
                let reason = (error as Error?)?.localizedDescription ?? "Unknown adhoc error"
                throw NetplayError.connectionFailed(reason)
            }
            lastNetplayContext = PPSSPPNetplayContext(role: role, settings: settings, effectiveServerAddress: effectiveAddress)
        }
    }

    /// Stop the current adhoc session.
    public func stopNetplay() async {
        await MainActor.run {
            _bridge.stopAdhoc()
            lastNetplayContext = nil
        }
    }

    // MARK: State

    public var netplayState: NetplayState { currentNetplayState }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        adhocStatePublisher
    }
}

// MARK: - NetplayRole helpers

private extension NetplayRole {
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
    /// Builds a room descriptor from available PPSSPP context.
    static func ppssppRoom(
        id: UUID = UUID(),
        address: String,
        port: UInt16,
        context: PPSSPPNetplayContext?
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }
        let isPasswordProtected = !(settings?.password?.isEmpty ?? true)
        let allowsSpectators = settings?.allowSpectators ?? false
        return NetplayRoom(
            id: id,
            hostName: nickname ?? "PPSSPP",
            gameName: "",
            gameHash: "",
            coreIdentifier: CorePlist.pvCoreIdentifier,
            maxPlayers: settings?.maxPlayers ?? 2,
            currentPlayers: 1,
            isLAN: settings?.relayServer == nil,
            hostAddress: address,
            port: port,
            isPasswordProtected: isPasswordProtected,
            allowsSpectators: allowsSpectators,
            discoverySource: .manual
        )
    }
}
