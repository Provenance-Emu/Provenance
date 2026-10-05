//
//  MednafenGameCore+PVNetplayCapable.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts MednafenGameCore (via its internal bridge) to PVNetplayCapable so that
//  PVNetplayManager can drive Mednafen netplay sessions natively.
//
//  Mednafen netplay model:
//    - Every player, the host included, is a client of a `mednafen-server`.
//    - "Hosting" starts the server embedded in the app (its own thread) and
//      connects this device's client to it over 127.0.0.1.
//    - "Joining" connects to the host device's LAN address and port.
//    - Spectating joins with no controller (`netplay.localplayers` = 0).
//    - Every player needs the same game and the same Mednafen build.
//    - The connection is made on the emulation thread, so it completes once
//      the game is running (not while the pause menu is up).
//

import Foundation
import Combine
import PVNetplay
import PVLogging
import MednafenGameCoreBridge
import ObjectiveC

// MARK: - Constants

private enum MednafenNetplayDefaults {
    /// mednafen-server's conventional port, used when a role carries port 0.
    /// A non-zero port (the UI's default included) is used as given: the
    /// joiner gets it from the host's room, so both sides agree.
    static let port: UInt16 = 4046
    /// The host's own client joins the embedded server here.
    static let loopbackHost = "127.0.0.1"
    static let fallbackNickname = "Player"
    static let coreIdentifier = "com.provenance.mednafen"
    static let hostName = "Mednafen"
    /// Server connection limits; the upper one is mednafen-server's MaxClientsPerGame.
    static let clientLimit = 2...32
    /// How often the bridge's connection state is checked for changes.
    static let pollInterval: TimeInterval = 0.5
}

// MARK: - Session context

/// The running session, stored via ObjC associated objects.
private final class MednafenNetplayContext: NSObject {
    let sessionID = UUID()  // stable across polls — prevents UUID churn in the UI
    let role: NetplayRole
    let settings: NetplaySettings
    /// The address other players connect to (host) or that we connected to (client).
    let advertisedHost: String
    let port: UInt16

    var isHost: Bool {
        if case .host = role { return true }
        return false
    }

    init(role: NetplayRole, settings: NetplaySettings, advertisedHost: String, port: UInt16) {
        self.role = role
        self.settings = settings
        self.advertisedHost = advertisedHost
        self.port = port
    }
}

/// What the UI needs to hear about. `NetplayState ==` compares room ids only,
/// so a host's player count change would not count as a change.
private enum MednafenNetplaySignature: Equatable {
    case idle
    case hosting(players: Int)
    case connecting
    case connected
    case disconnected
}

/// The polling timer and the last state it published.
private final class MednafenNetplayPoller: NSObject {
    var cancellable: AnyCancellable?
    var lastSignature: MednafenNetplaySignature?
}

// MARK: - Associated-object keys

/// Stable addresses for `objc_getAssociatedObject` / `objc_setAssociatedObject`; values are unused.
private enum AssocKeys {
    nonisolated(unsafe) static var context: UInt8 = 0
    nonisolated(unsafe) static var queue: UInt8 = 0
    nonisolated(unsafe) static var subject: UInt8 = 0
    nonisolated(unsafe) static var poller: UInt8 = 0
}

// MARK: - PVNetplayCapable

// MednafenGameCore is ObjC-backed. The bridge's netplay state is atomic and
// safe to read from any thread; session setup is serialised on _netplayQueue.
extension MednafenGameCore: PVNetplayCapable {

    public var supportsNetplay: Bool { _bridge.mednafenNetplaySupported }

    public var netplayEngineName: String { "Mednafen" }

    // MARK: - Associated-object helpers

    // OBJC_ASSOCIATION_RETAIN (atomic) — written from _netplayQueue, read from the
    // main-thread polling timer, so a non-atomic policy would be a data race.
    private var _netplayContext: MednafenNetplayContext? {
        get { objc_getAssociatedObject(self, &AssocKeys.context) as? MednafenNetplayContext }
        set { objc_setAssociatedObject(self, &AssocKeys.context, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Serial queue serialising all session setup and teardown.
    private var _netplayQueue: DispatchQueue {
        if let q = objc_getAssociatedObject(self, &AssocKeys.queue) as? DispatchQueue { return q }
        let q = DispatchQueue(label: "com.provenance.mednafen.netplay", qos: .userInitiated)
        objc_setAssociatedObject(self, &AssocKeys.queue, q, .OBJC_ASSOCIATION_RETAIN)
        return q
    }

    private var _stateSubject: CurrentValueSubject<NetplayState, Never> {
        if let existing = objc_getAssociatedObject(self, &AssocKeys.subject)
            as? CurrentValueSubject<NetplayState, Never> {
            return existing
        }
        let subject = CurrentValueSubject<NetplayState, Never>(.idle)
        // OBJC_ASSOCIATION_RETAIN (atomic) — sent on main, observed by PVNetplayManager.
        objc_setAssociatedObject(self, &AssocKeys.subject, subject, .OBJC_ASSOCIATION_RETAIN)
        return subject
    }

    /// Main thread only.
    private var _poller: MednafenNetplayPoller {
        if let existing = objc_getAssociatedObject(self, &AssocKeys.poller) as? MednafenNetplayPoller {
            return existing
        }
        let poller = MednafenNetplayPoller()
        objc_setAssociatedObject(self, &AssocKeys.poller, poller, .OBJC_ASSOCIATION_RETAIN)
        return poller
    }

    // MARK: - Control

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard supportsNetplay else { throw NetplayError.unsupported }
        switch _bridge.mednafenNetplayStatus {
        case .connecting, .connected:
            throw NetplayError.alreadyActive
        default:
            break  // idle, or a session that ended on its own — start over
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _netplayQueue.async { [weak self] in
                guard let self else { continuation.resume(throwing: NetplayError.bridgeNotReady); return }
                do {
                    try self.beginSession(role: role, settings: settings)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        await MainActor.run { self.startPolling() }
    }

    public func stopNetplay() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            _netplayQueue.async { [weak self] in
                self?._bridge.netplayDisconnect()
                MednafenGameCoreBridge.stopNetplayServer()
                self?._netplayContext = nil
                DispatchQueue.main.async {
                    self?.stopPolling()
                    self?._stateSubject.send(.idle)
                    continuation.resume()
                }
            }
        }
    }

    /// On `_netplayQueue`. Hosting starts the embedded server first (throws if
    /// the port can't be bound), then this device joins it like any player.
    private func beginSession(role: NetplayRole, settings: NetplaySettings) throws {
        // A session that ended on its own may have left a server running.
        MednafenGameCoreBridge.stopNetplayServer()

        let nickname = settings.nickname.isEmpty ? MednafenNetplayDefaults.fallbackNickname : settings.nickname
        let password = settings.password ?? ""
        let connectHost: String
        let advertisedHost: String
        let port: UInt16
        var spectator = false

        switch role {
        case .host(let rolePort):
            port = Self.resolvedPort(rolePort)
            let clients = min(max(settings.maxPlayers, MednafenNetplayDefaults.clientLimit.lowerBound),
                              MednafenNetplayDefaults.clientLimit.upperBound)
            do {
                try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: password, maxClients: clients)
            } catch {
                throw NetplayError.connectionFailed(error.localizedDescription)
            }
            connectHost = MednafenNetplayDefaults.loopbackHost
            advertisedHost = NetplayLocalAddresses.current().first ?? ""
        case .client(let host, let rolePort):
            port = Self.resolvedPort(rolePort)
            connectHost = host
            advertisedHost = host
        case .spectator(let host, let rolePort):
            port = Self.resolvedPort(rolePort)
            connectHost = host
            advertisedHost = host
            spectator = true
        }

        do {
            try _bridge.netplayConnect(toHost: connectHost,
                                       port: port,
                                       nickname: nickname,
                                       password: password,
                                       spectator: spectator)
        } catch {
            MednafenGameCoreBridge.stopNetplayServer()
            throw NetplayError.connectionFailed(error.localizedDescription)
        }

        _netplayContext = MednafenNetplayContext(role: role, settings: settings,
                                                 advertisedHost: advertisedHost, port: port)
    }

    // MARK: - State

    public var netplayState: NetplayState {
        guard let ctx = _netplayContext else { return .idle }
        switch _bridge.mednafenNetplayStatus {
        case .idle:
            return .idle
        case .disconnected:
            return .disconnected(reason: .networkError)
        case .connecting:
            // The server is listening as soon as hosting starts; the host's own
            // client logs in once the game runs.
            return ctx.isHost ? .hosting(room: room(for: ctx)) : .connecting(to: room(for: ctx))
        case .connected:
            if ctx.isHost {
                return .hosting(room: room(for: ctx))
            }
            let session = NetplaySession(
                room: room(for: ctx),
                role: ctx.role,
                peers: [],
                frameDelay: ctx.settings.frameDelay,
                isRollbackEnabled: false
            )
            return .connected(session: session)
        @unknown default:
            return .idle
        }
    }

    /// Emits on every change seen by the polling timer, which runs from
    /// `startNetplay` until `stopNetplay`.
    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Helpers

    private func room(for ctx: MednafenNetplayContext) -> NetplayRoom {
        // The server counts players once they have logged in; the host is
        // always one of them.
        let players = ctx.isHost ? max(MednafenGameCoreBridge.netplayServerPlayerCount, 1) : 1
        return NetplayRoom(
            id: ctx.sessionID,
            hostName: MednafenNetplayDefaults.hostName,
            gameName: "",
            gameHash: "",
            coreIdentifier: MednafenNetplayDefaults.coreIdentifier,
            maxPlayers: ctx.settings.maxPlayers,
            currentPlayers: players,
            isLAN: true,
            hostAddress: ctx.advertisedHost,
            port: ctx.port
        )
    }

    private static func signature(of state: NetplayState) -> MednafenNetplaySignature {
        switch state {
        case .idle: return .idle
        case .hosting(let room): return .hosting(players: room.currentPlayers)
        case .connecting: return .connecting
        case .connected: return .connected
        case .disconnected: return .disconnected
        }
    }

    /// Main thread.
    private func startPolling() {
        let poller = _poller
        poller.cancellable?.cancel()
        poller.lastSignature = nil
        publishIfChanged()
        poller.cancellable = Timer.publish(every: MednafenNetplayDefaults.pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.publishIfChanged() }
    }

    /// Main thread.
    private func stopPolling() {
        let poller = _poller
        poller.cancellable?.cancel()
        poller.cancellable = nil
        poller.lastSignature = nil
    }

    /// Main thread.
    private func publishIfChanged() {
        let state = netplayState
        let signature = Self.signature(of: state)
        let poller = _poller
        guard signature != poller.lastSignature else { return }
        poller.lastSignature = signature
        if case .disconnected = state, let message = _bridge.mednafenNetplayLastMessage {
            WLOG("[Mednafen Netplay] Session ended: \(message)")
        }
        _stateSubject.send(state)
    }

    /// Port 0 means "Mednafen's default"; anything else is used as given.
    private static func resolvedPort(_ port: UInt16) -> UInt16 {
        port == 0 ? MednafenNetplayDefaults.port : port
    }
}
