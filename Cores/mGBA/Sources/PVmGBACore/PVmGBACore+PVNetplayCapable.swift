//
//  PVmGBACore+PVNetplayCapable.swift
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVmGBACore to PVNetplayCapable so that PVNetplayManager can drive
//  mGBA link-cable sessions over a LAN TCP connection.
//
//  mGBA link-cable model
//  ──────────────────────
//    Host   (player 1 / master): .host(port:)     → startLinkHostOnPort
//    Client (player 2 / slave):  .client(host:port:) → joinLinkAtHost:port:
//    Spectator:                  falls back to client (link cable is 2-player only)
//
//  The actual byte exchange is performed by a custom GBASIODriver installed
//  into the running mGBA core by PVmGBAGameCoreBridge+Netplay.mm.  The
//  Swift layer here only manages the session lifecycle and publishes state
//  changes for the UI.
//

import Foundation
import Combine
import PVNetplay
import PVmGBABridge
import ObjectiveC

// MARK: - Session context

/// Boxes session metadata so it can be stored via ObjC associated objects.
private final class MGBALinkContext: NSObject {
    /// Stable IDs for the lifetime of this session — prevents UUID churn in
    /// published state updates that use value-based equality.
    let roomID: UUID
    let sessionID: UUID
    let role: NetplayRole
    let settings: NetplaySettings

    init(role: NetplayRole, settings: NetplaySettings) {
        self.roomID    = UUID()
        self.sessionID = UUID()
        self.role      = role
        self.settings  = settings
    }
}

// MARK: - Associated-object keys

private enum MGBALinkAssocKeys {
    nonisolated(unsafe) static var context: UInt8 = 0
    nonisolated(unsafe) static var subject: UInt8 = 0
    nonisolated(unsafe) static var cancellable: UInt8 = 0
}

// MARK: - Private helpers

private extension PVmGBACore {

    var _linkContext: MGBALinkContext? {
        get { objc_getAssociatedObject(self, &MGBALinkAssocKeys.context) as? MGBALinkContext }
        set { objc_setAssociatedObject(self, &MGBALinkAssocKeys.context, newValue,
                                       .OBJC_ASSOCIATION_RETAIN) }
    }

    var _stateSubject: CurrentValueSubject<NetplayState, Never> {
        if let existing = objc_getAssociatedObject(self, &MGBALinkAssocKeys.subject)
            as? CurrentValueSubject<NetplayState, Never> {
            return existing
        }
        let subject = CurrentValueSubject<NetplayState, Never>(.idle)
        objc_setAssociatedObject(self, &MGBALinkAssocKeys.subject, subject,
                                 .OBJC_ASSOCIATION_RETAIN)
        return subject
    }

    var _pollingCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &MGBALinkAssocKeys.cancellable) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &MGBALinkAssocKeys.cancellable, newValue,
                                       .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Compute the current NetplayState by examining the bridge's link status.
    var _currentNetplayState: NetplayState {
        let status = _bridge.linkStatus
        let ctx    = _linkContext

        switch status {
        case .idle:
            return .idle

        case .hosting:
            let room = NetplayRoom.mgbaRoom(id: ctx?.roomID ?? UUID(),
                                            address: "0.0.0.0",
                                            context: ctx)
            return .hosting(room: room)

        case .connected:
            guard let ctx else { return .idle }

            let (hostAddr, port): (String, UInt16)
            switch ctx.role {
            case .host(let p):
                hostAddr = "127.0.0.1"
                port     = p
            case .client(let h, let p),
                 .spectator(let h, let p):
                hostAddr = h
                port     = p
            }

            let room = NetplayRoom.mgbaRoom(id: ctx.roomID,
                                            address: hostAddr,
                                            context: ctx)

            // Host is still the logical host even after the client connects.
            if ctx.role.isHost {
                return .hosting(room: room)
            }

            let session = NetplaySession(
                id: ctx.sessionID,
                room: room,
                role: .client(host: hostAddr, port: port),
                peers: [],
                frameDelay: 0,        // lockstep — no frame delay concept
                isRollbackEnabled: false
            )
            return .connected(session: session)

        @unknown default:
            return .idle
        }
    }

    /// Start polling bridge link status once per second and push state updates.
    func _startStatusPolling() {
        let cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let newState = self._currentNetplayState
                if self._stateSubject.value != newState {
                    self._stateSubject.send(newState)
                }
            }
        _pollingCancellable = cancellable
    }

    func _stopStatusPolling() {
        _pollingCancellable = nil
    }
}

// MARK: - PVNetplayCapable

extension PVmGBACore: PVNetplayCapable {

    public var supportsNetplay: Bool { true }

    public var netplayEngineName: String { "mGBA Link" }

    // MARK: Control

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard _bridge.linkStatus == .idle else {
            throw NetplayError.alreadyActive
        }

        try await MainActor.run {
            var nsError: NSError?
            let success: Bool

            switch role {
            case .host(let port):
                success = _bridge.startLinkHost(onPort: port, error: &nsError)

            case .client(let host, let port):
                success = _bridge.joinLink(atHost: host, port: port, error: &nsError)

            case .spectator(let host, let port):
                // Link cable is 2-player only; spectator connects as the second player.
                success = _bridge.joinLink(atHost: host, port: port, error: &nsError)
            }

            if !success {
                let reason = nsError?.localizedDescription ?? "Unknown error"
                throw NetplayError.connectionFailed(reason)
            }

            _linkContext = MGBALinkContext(role: role, settings: settings)
            _stateSubject.send(_currentNetplayState)
            _startStatusPolling()
        }
    }

    public func stopNetplay() async {
        await MainActor.run {
            _bridge.stopLink()
            _linkContext = nil
            _stopStatusPolling()
            _stateSubject.send(.idle)
        }
    }

    // MARK: State

    public var netplayState: NetplayState { _currentNetplayState }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _stateSubject.eraseToAnyPublisher()
    }
}

// MARK: - NetplayRoom factory

private extension NetplayRoom {
    /// Builds a room descriptor from available mGBA link context.
    static func mgbaRoom(
        id: UUID = UUID(),
        address: String,
        context: MGBALinkContext?
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }

        // Resolve port: for host we use the port from the role; default to 0 if unknown.
        let port: UInt16
        if case .host(let p) = context?.role {
            port = p
        } else if case .client(_, let p) = context?.role {
            port = p
        } else {
            port = 0
        }

        return NetplayRoom(
            id: id,
            hostName: nickname ?? "mGBA",
            gameName: "",
            gameHash: "",
            coreIdentifier: CorePlist.pvCoreIdentifier,
            maxPlayers: 2,           // GBA link cable supports 2 players
            currentPlayers: 1,
            isLAN: settings?.relayServer == nil,
            hostAddress: address,
            port: port,
            isPasswordProtected: !(settings?.password?.isEmpty ?? true),
            allowsSpectators: false, // Link cable has no spectator concept
            discoverySource: .manual
        )
    }
}
