//
//  PVDolphinCore+PVNetplayCapable.swift
//  PVDolphin
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVDolphinCore (via its internal ObjC bridge) to PVNetplayCapable
//  so that PVNetplayManager can drive Dolphin netplay sessions natively.
//
//  Dolphin netplay model (as mapped to PVNetplayCapable):
//    .host(port:)               → startNetplayHost(onPort:…) — starts a
//                                  NetPlayServer, selects the loaded game on
//                                  it, and joins it as player 1.
//    .client(host:port:)        → joinNetplay(host:…) — direct-IP join.
//    .spectator(host:port:)     → mapped to .client (Dolphin has no spectator
//                                  role; peer joins as an inactive controller).
//
//  Traversal (Dolphin's relay, stun.dolphin-emu.org:6262): when
//  settings.relayServer is non-nil (any value), the host registers with the
//  relay and publishes the code it gets as room.traversalCode, and a client
//  passes that code as `host` to join by code instead of by address.
//
//  Every player boots the game together (`netplayHostStartsGame`): the host's
//  Start Game makes each player reboot the running core into the netplay
//  session (PVDolphinCore+NetplayBoot.h), and back to the local game when the
//  netplay game ends.
//

import Foundation
import Combine
import PVNetplay
import PVSettings
import PVLogging
import ObjectiveC

// MARK: - Session context

/// Boxes role + settings so they can be stored via ObjC associated objects.
private final class DolphinNetplayContext: NSObject, Sendable {
    let sessionID: UUID
    let role: NetplayRole
    let settings: NetplaySettings

    init(role: NetplayRole, settings: NetplaySettings) {
        self.sessionID = UUID()
        self.role      = role
        self.settings  = settings
    }
}

private enum DolphinNetplayDefaults {
    static let coreIdentifier = "com.provenance.dolphin"
    static let port: UInt16 = 2626
    static let maxPlayers = 4
    static let pollInterval: TimeInterval = 1.0
    /// Dolphin's pad buffer ceiling, as the bridge clamps it.
    static let maxFrameDelay = 127
}

// MARK: - Associated-object keys

private enum AssocKeys {
    nonisolated(unsafe) static var context:    UInt8 = 0
    nonisolated(unsafe) static var queue:      UInt8 = 0
    nonisolated(unsafe) static var subject:    UInt8 = 0
    nonisolated(unsafe) static var cancellable: UInt8 = 0
}

// MARK: - PVNetplayCapable

// PVDolphinCore is ObjC-backed; its netplay state is mutated by Dolphin's
// netplay threads.  @unchecked Sendable is intentional — callers must not
// mutate netplay state concurrently.
extension PVDolphinCore: PVNetplayCapable {

    public var supportsNetplay: Bool { _bridge.dolphinNetplaySupported }

    public var netplayEngineName: String { "Dolphin" }

    /// Dolphin starts every player together, from the host's Start Game.
    public var netplayHostStartsGame: Bool { true }

    /// Host only: every player, the host included, reboots into the game.
    public func startNetplayGame() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _netplayQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NetplayError.bridgeNotReady)
                    return
                }
                do {
                    try self._bridge.requestDolphinNetplayGameStart()
                    continuation.resume()
                } catch let error as PVDolphinNetplayError {
                    switch error.code {
                    case .gameMismatch:
                        continuation.resume(throwing: NetplayError.romMismatch)
                    case .invalidSettings:
                        continuation.resume(throwing: NetplayError.invalidSettings(error.localizedDescription))
                    case .unsupported:
                        continuation.resume(throwing: NetplayError.unsupported)
                    default:
                        continuation.resume(throwing: NetplayError.connectionFailed(error.localizedDescription))
                    }
                } catch {
                    continuation.resume(throwing: NetplayError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Associated-object helpers

    private var _netplayContext: DolphinNetplayContext? {
        get { objc_getAssociatedObject(self, &AssocKeys.context) as? DolphinNetplayContext }
        set { objc_setAssociatedObject(self, &AssocKeys.context, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Serial queue for all bridge netplay calls.
    private var _netplayQueue: DispatchQueue {
        if let q = objc_getAssociatedObject(self, &AssocKeys.queue) as? DispatchQueue { return q }
        let q = DispatchQueue(label: "com.provenance.dolphin.netplay", qos: .userInitiated)
        objc_setAssociatedObject(self, &AssocKeys.queue, q, .OBJC_ASSOCIATION_RETAIN)
        return q
    }

    private var _stateSubject: CurrentValueSubject<NetplayState, Never> {
        if let s = objc_getAssociatedObject(self, &AssocKeys.subject)
            as? CurrentValueSubject<NetplayState, Never> { return s }
        let s = CurrentValueSubject<NetplayState, Never>(.idle)
        objc_setAssociatedObject(self, &AssocKeys.subject, s, .OBJC_ASSOCIATION_RETAIN)
        return s
    }

    private var _pollingCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &AssocKeys.cancellable) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &AssocKeys.cancellable, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    // MARK: - Control

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard supportsNetplay else { throw NetplayError.unsupported }
        guard _bridge.dolphinNetplayStatus == .idle else { throw NetplayError.alreadyActive }

        let context = DolphinNetplayContext(role: role, settings: settings)
        let useTraversal = settings.relayServer != nil

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _netplayQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NetplayError.bridgeNotReady)
                    return
                }

                // Captured by the bridge when the session starts.
                let sessionID = context.sessionID
                self._bridge.dolphinNetplayEventHandler = { [weak self] event, message in
                    self?._handleNetplayEvent(event, message: message, sessionID: sessionID)
                }

                do {
                    switch role {
                    case .host(let port):
                        try self._bridge.startNetplayHost(
                            onPort: port == 0 ? UInt16(settings.port) : port,
                            password: settings.password,
                            maxPlayers: settings.maxPlayers,
                            useTraversal: useTraversal
                        )

                    case .client(let host, let port), .spectator(let host, let port):
                        // Dolphin has no spectator role; a spectator joins as a client.
                        // With traversal, `host` is the host's traversal code.
                        try self._bridge.joinNetplay(
                            host: useTraversal ? "" : host,
                            port: port == 0 ? UInt16(settings.port) : port,
                            traversalCode: useTraversal ? host : nil,
                            password: settings.password
                        )
                    }

                    self._netplayContext = context
                    // frameDelay is Dolphin's pad buffer; clamp before converting.
                    let clampedFrameDelay = max(0, min(settings.frameDelay, DolphinNetplayDefaults.maxFrameDelay))
                    self._bridge.setNetplayInputBufferSize(UInt32(clamping: clampedFrameDelay))
                    continuation.resume()
                } catch {
                    self._bridge.dolphinNetplayEventHandler = nil
                    continuation.resume(throwing: NetplayError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }

    public func stopNetplay() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            _netplayQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                self._bridge.stopNetplay()
                self._bridge.dolphinNetplayEventHandler = nil
                self._netplayContext = nil
                DispatchQueue.main.async {
                    self._pollingCancellable?.cancel()
                    self._pollingCancellable = nil
                    self._stateSubject.send(.idle)
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Events

    /// Main thread (the bridge delivers events there).
    private func _handleNetplayEvent(_ event: PVDolphinNetplayEvent, message: String?, sessionID: UUID) {
        // Drop events from a session that has already been stopped or replaced.
        guard _netplayContext?.sessionID == sessionID else { return }

        let reason: DisconnectReason
        switch event {
        case .connectionLost:
            if case .host = _netplayContext?.role { reason = .networkError } else { reason = .hostClosed }
        case .connectionError:
            reason = .networkError
        case .desync:
            // Dolphin keeps running after a desync; the bridge already showed it.
            WLOG("[Dolphin Netplay] \(message ?? "Desync")")
            return
        case .traversalCodeReady, .traversalFailed, .playersChanged:
            _stateSubject.send(netplayState)
            return
        @unknown default:
            return
        }

        WLOG("[Dolphin Netplay] Session ended: \(message ?? "connection lost")")
        _netplayQueue.async { [weak self] in
            guard let self, self._netplayContext?.sessionID == sessionID else { return }
            self._bridge.stopNetplay()
            self._bridge.dolphinNetplayEventHandler = nil
            self._netplayContext = nil
            DispatchQueue.main.async {
                self._pollingCancellable?.cancel()
                self._pollingCancellable = nil
                self._stateSubject.send(.disconnected(reason: reason))
            }
        }
    }

    // MARK: - State

    public var netplayState: NetplayState {
        let ctx = _netplayContext
        let nickname = ctx?.settings.nickname ?? ""
        let playerName = nickname.isEmpty ? PVSettingsWrapper.resolvedPlayerUsername : nickname
        let playerCount = max(1, _bridge.dolphinNetplayPlayerCount)

        switch _bridge.dolphinNetplayStatus {
        case .idle:
            return .idle

        case .hosting:
            let effectivePort: UInt16
            if case .host(let rolePort) = ctx?.role, rolePort > 0 {
                effectivePort = rolePort
            } else {
                effectivePort = ctx?.settings.port ?? DolphinNetplayDefaults.port
            }
            // Nil for direct sessions, and until the relay assigns a code.
            let traversalCode = _bridge.dolphinTraversalCode
            let room = NetplayRoom(
                id: ctx?.sessionID ?? UUID(),
                hostName: playerName,
                gameName: "",
                gameHash: "",
                coreIdentifier: DolphinNetplayDefaults.coreIdentifier,
                maxPlayers: ctx?.settings.maxPlayers ?? DolphinNetplayDefaults.maxPlayers,
                currentPlayers: playerCount,
                isLAN: traversalCode == nil,
                hostAddress: traversalCode ?? "0.0.0.0",
                port: effectivePort,
                traversalCode: traversalCode
            )
            return .hosting(room: room)

        case .connected:
            let role = ctx?.role ?? .client(host: "0.0.0.0", port: DolphinNetplayDefaults.port)
            let (hostAddr, port) = _resolvedHostPort(for: role, settings: ctx?.settings)
            let usesTraversal = ctx?.settings.relayServer != nil
            let room = NetplayRoom(
                id: ctx?.sessionID ?? UUID(),
                hostName: playerName,
                gameName: "",
                gameHash: "",
                coreIdentifier: DolphinNetplayDefaults.coreIdentifier,
                maxPlayers: ctx?.settings.maxPlayers ?? DolphinNetplayDefaults.maxPlayers,
                currentPlayers: playerCount,
                isLAN: !usesTraversal,
                hostAddress: hostAddr,
                port: port,
                traversalCode: usesTraversal ? hostAddr : nil
            )
            let session = NetplaySession(
                room: room,
                role: role,
                peers: [],
                frameDelay: ctx?.settings.frameDelay ?? 0,
                isRollbackEnabled: false
            )
            return .connected(session: session)

        @unknown default:
            return .idle
        }
    }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        let subject = _stateSubject
        if _pollingCancellable == nil {
            _pollingCancellable = Timer.publish(every: DolphinNetplayDefaults.pollInterval, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    let state = self.netplayState
                    subject.send(state)
                    if !state.isActive {
                        self._pollingCancellable?.cancel()
                        self._pollingCancellable = nil
                    }
                }
        }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Helpers

    private func _resolvedHostPort(
        for role: NetplayRole,
        settings: NetplaySettings?
    ) -> (String, UInt16) {
        let defaultPort: UInt16 = settings?.port ?? DolphinNetplayDefaults.port
        switch role {
        case .host(let rolePort):
            // Use the port explicitly provided in the role; fall back to settings.port.
            return ("127.0.0.1", rolePort > 0 ? rolePort : defaultPort)
        case .client(let host, let port), .spectator(let host, let port):
            return (host, port == 0 ? defaultPort : port)
        }
    }
}
