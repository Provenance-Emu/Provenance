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

// MARK: - Sendable

/// PVmGBACore is an ObjC class whose thread safety is enforced by the
/// emulator core's own serialisation. We declare @unchecked Sendable so
/// Swift concurrency does not reject the PVNetplayCapable conformance.
extension PVmGBACore: @unchecked Sendable {}

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
            // Return .idle when context is not yet set to avoid generating a
            // new UUID on every poll tick (which causes spurious state updates).
            guard let ctx else { return .idle }
            let room = NetplayRoom.mgbaRoom(id: ctx.roomID,
                                            address: "0.0.0.0",
                                            context: ctx,
                                            currentPlayers: 1)
            return .hosting(room: room)

        case .connected:
            guard let ctx else { return .idle }

            let (hostAddr, port): (String, UInt16)
            switch ctx.role {
            case .host(let p):
                // Avoid advertising loopback (127.0.0.1) as the room address —
                // it is not reachable from other devices. Use "0.0.0.0" to
                // indicate "bound to all interfaces" without a concrete LAN IP.
                hostAddr = "0.0.0.0"
                port     = p
            case .client(let h, let p),
                 .spectator(let h, let p):
                hostAddr = h
                port     = p
            }

            let room = NetplayRoom.mgbaRoom(id: ctx.roomID,
                                            address: hostAddr,
                                            context: ctx,
                                            currentPlayers: 2)

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

                // Detect unexpected peer disconnect: bridge returned to idle with
                // a recorded error. Translate to .disconnected rather than .idle
                // so the UI can show a meaningful message, then clean up.
                if let disconnectError = self._bridge.lastDisconnectError,
                   self._bridge.linkStatus == .idle {
                    let nsErr = disconnectError as NSError
                    let reason: DisconnectReason
                    if nsErr.domain == PVmGBALinkErrorDomain as String &&
                       nsErr.code == PVmGBALinkError.peerDisconnected.rawValue {
                        reason = .peerDisconnected
                    } else {
                        reason = .networkError
                    }
                    self._stateSubject.send(.disconnected(reason: reason))
                    self._linkContext = nil
                    self._stopStatusPolling()
                    // stopLink clears lastDisconnectError and releases all resources.
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

        // This implementation is LAN-only; relay/WAN sessions are not supported.
        if settings.relayServer != nil {
            throw NetplayError.invalidSettings("mGBA link-cable netplay supports LAN only. Remove the relay server setting.")
        }

        // Perform the potentially blocking bridge calls off the main actor.
        // joinLinkAtHost:port:error: performs a synchronous select(5s) on the
        // calling thread, which would freeze the UI if called on MainActor.
        //
        // `Task.detached` does not inherit the caller's cancellation scope, so we
        // wrap with `withTaskCancellationHandler` to propagate cancellation: if the
        // caller cancels while we are blocked in connect(), the handler calls
        // stopLink() which closes the socket and unblocks the connect() syscall.
        let bridge = _bridge
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // NOTE: Task.detached is used so the potentially-blocking socket
                // operations (connect with 5-second timeout, accept) do not run on
                // the main actor.  Cancellation is handled by the `onCancel` closure
                // below, which calls stopLink() to close sockets and unblock any
                // in-progress syscall.  Task.isCancelled is NOT checked here because
                // Task.detached does not inherit the caller's cancellation scope.
                Task.detached(priority: .userInitiated) {
                    var nsError: NSError?
                    let success: Bool

                    switch role {
                    case .host(let port):
                        success = bridge.startLinkHost(onPort: port, error: &nsError)

                    case .client(let host, let port):
                        success = bridge.joinLink(atHost: host, port: port, error: &nsError)

                    case .spectator(let host, let port):
                        // Link cable is 2-player only; spectator connects as the second player.
                        success = bridge.joinLink(atHost: host, port: port, error: &nsError)
                    }

                    if !success {
                        let reason = nsError?.localizedDescription ?? "Unknown error"
                        continuation.resume(throwing: NetplayError.connectionFailed(reason))
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: {
            // Fired when the caller's task is cancelled. Calling stopLink() closes
            // all sockets, which unblocks any in-progress connect()/accept() syscall
            // and causes the detached task to fail cleanly without a dangling session.
            bridge.stopLink()
        }

        // Only mutate state and notify observers on the main actor.
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
    /// Builds a room descriptor from available mGBA link context.
    static func mgbaRoom(
        id: UUID = UUID(),
        address: String,
        context: MGBALinkContext?,
        currentPlayers: Int = 1
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }

        // Resolve port: for host/client/spectator we use the port from the role; default to 0 if unknown.
        let port: UInt16
        if case .host(let p) = context?.role {
            port = p
        } else if case .client(_, let p) = context?.role {
            port = p
        } else if case .spectator(_, let p) = context?.role {
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
            currentPlayers: currentPlayers,
            isLAN: settings?.relayServer == nil,
            hostAddress: address,
            port: port,
            isPasswordProtected: !(settings?.password?.isEmpty ?? true),
            allowsSpectators: false, // Link cable has no spectator concept
            discoverySource: .manual
        )
    }
}
