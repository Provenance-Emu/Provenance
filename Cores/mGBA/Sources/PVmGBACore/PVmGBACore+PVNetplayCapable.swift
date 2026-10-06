//
//  PVmGBACore+PVNetplayCapable.swift
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVmGBACore to PVNetplayCapable: a GBA link cable between two
//  devices over the network.
//
//    Host   (player 1): .host(port:)        → startLinkHost(onPort:password:)
//    Client (player 2): .client(host:port:) → joinLink(atHost:port:password:)
//    Spectator: not supported (a link cable has no spectator seat)
//
//  The two GBAs run in lockstep (PVmGBANetLinkDriver.c in the bridge). Each
//  multiplayer transfer costs the host about one network round trip, so
//  trading and battles work over a LAN at reduced speed while the link is
//  busy; real-time multiplayer games are likely too slow. This layer only
//  manages the session and publishes its state.
//

import Foundation
import Combine
import PVNetplay
import PVLogging
import PVmGBABridge
import ObjectiveC

// MARK: - Sendable

/// PVmGBACore is an ObjC class whose thread safety is enforced by the
/// emulator core's own serialisation. We declare @unchecked Sendable so
/// Swift concurrency does not reject the PVNetplayCapable conformance.
extension PVmGBACore: @unchecked Sendable {}

/// PVmGBAGameCoreBridge is used from a detached task for the blocking join.
/// Its link methods are thread-safe.
extension PVmGBAGameCoreBridge: @unchecked Sendable {}

// MARK: - Session context

/// Boxes session metadata so it can be stored via ObjC associated objects.
private final class MGBALinkContext: NSObject {
    /// Fixed for the session so published states compare equal between polls.
    let roomID: UUID
    let sessionID: UUID
    let createdAt: Date
    let role: NetplayRole
    let settings: NetplaySettings
    /// The address another device should dial: the host's first LAN address,
    /// or the address the client dialled.
    let hostAddress: String

    init(role: NetplayRole, settings: NetplaySettings) {
        self.roomID = UUID()
        self.sessionID = UUID()
        self.createdAt = Date()
        self.role = role
        self.settings = settings
        switch role {
        case .host:
            self.hostAddress = NetplayLocalAddresses.current().first ?? ""
        case .client(let host, _), .spectator(let host, _):
            self.hostAddress = host
        }
    }
}

// MARK: - Associated-object keys

private enum MGBALinkAssocKeys {
    nonisolated(unsafe) static var context: UInt8 = 0
    nonisolated(unsafe) static var subject: UInt8 = 0
    nonisolated(unsafe) static var cancellable: UInt8 = 0
}

/// GBA link cables join two consoles in this implementation.
private let mgbaLinkMaxPlayers = 2

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

    /// The current NetplayState, from the bridge's link status.
    var _currentNetplayState: NetplayState {
        guard let ctx = _linkContext else { return .idle }

        switch _bridge.linkStatus {
        case .idle:
            return .idle

        case .hosting:
            return .hosting(room: .mgbaRoom(context: ctx, port: _bridge.linkPort, currentPlayers: 1))

        case .connected:
            let room = NetplayRoom.mgbaRoom(context: ctx, port: _bridge.linkPort,
                                            currentPlayers: mgbaLinkMaxPlayers)
            // The host stays the room's host after the client joins.
            if ctx.role.isHost {
                return .hosting(room: room)
            }
            return .connected(session: NetplaySession(
                id: ctx.sessionID,
                room: room,
                role: ctx.role,
                peers: [],
                frameDelay: 0,        // lockstep — no frame delay concept
                isRollbackEnabled: false
            ))

        @unknown default:
            return .idle
        }
    }

    /// Poll the bridge's link status once per second and publish changes.
    func _startStatusPolling() {
        let cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }

                // The session ended on its own (peer left, timed out, hosting
                // failed): report why, then clean up.
                if let disconnectError = self._bridge.lastDisconnectError,
                   self._bridge.linkStatus == .idle {
                    let nsErr = disconnectError as NSError
                    let isLinkError = nsErr.domain == PVmGBALinkErrorDomain as String
                    let reason: DisconnectReason
                    if isLinkError && nsErr.code == PVmGBALinkError.peerDisconnected.rawValue {
                        reason = .peerDisconnected
                    } else if isLinkError && nsErr.code == PVmGBALinkError.timedOut.rawValue {
                        reason = .timeout
                    } else if isLinkError && nsErr.code == PVmGBALinkError.linkFailed.rawValue {
                        reason = .desync
                    } else {
                        reason = .networkError
                    }
                    WLOG("mGBA link ended: \(nsErr.localizedDescription)")
                    self._stateSubject.send(.disconnected(reason: reason))
                    self._linkContext = nil
                    self._stopStatusPolling()
                    self._bridge.stopLink()
                    return
                }

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
        if case .spectator = role {
            throw NetplayError.invalidSettings("A link cable has no spectator seat; join as a player.")
        }

        // Link cable connects directly to the host's address; a relay means
        // nothing to it, so ignore one rather than refuse to connect.
        if let relay = settings.relayServer {
            WLOG("mGBA netplay: ignoring relay \(relay); link cable connects directly")
        }

        // Joining blocks while it connects (up to 10 s), so run it off the
        // main actor. Cancelling the caller's task calls stopLink(), which
        // interrupts the connect.
        let bridge = _bridge
        let password = settings.password
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Task.detached(priority: .userInitiated) {
                    do {
                        switch role {
                        case .host(let port):
                            try bridge.startLinkHost(onPort: port, password: password)
                        case .client(let host, let port):
                            try bridge.joinLink(atHost: host, port: port, password: password)
                        case .spectator:
                            break // rejected above
                        }
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: NetplayError.connectionFailed(error.localizedDescription))
                    }
                }
            }
        } onCancel: {
            bridge.stopLink()
        }

        // Cancelled after the link came up: don't leave it running unowned.
        do {
            try Task.checkCancellation()
        } catch {
            bridge.stopLink()
            throw error
        }

        await MainActor.run {
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
    static func mgbaRoom(context: MGBALinkContext, port: UInt16, currentPlayers: Int) -> NetplayRoom {
        let nickname = context.settings.nickname
        return NetplayRoom(
            id: context.roomID,
            hostName: nickname.isEmpty ? "mGBA" : nickname,
            gameName: "",
            gameHash: "",
            coreIdentifier: CorePlist.pvCoreIdentifier,
            maxPlayers: mgbaLinkMaxPlayers,
            currentPlayers: currentPlayers,
            isLAN: true,
            hostAddress: context.hostAddress,
            port: port,
            isPasswordProtected: !(context.settings.password?.isEmpty ?? true),
            allowsSpectators: false,
            discoverySource: .manual,
            lastSeen: context.createdAt
        )
    }
}
