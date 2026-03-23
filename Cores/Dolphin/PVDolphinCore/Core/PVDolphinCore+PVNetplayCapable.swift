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
//    .host(port:)               → startNetplayHostOnPort: — starts a local
//                                  NetPlayServer and joins it as player 1.
//    .client(host:port:)        → joinNetplayHost:port:   — direct-IP join.
//    .spectator(host:port:)     → mapped to .client (Dolphin has no spectator
//                                  role; peer joins as an inactive controller).
//
//  Traversal (Dolphin STUN relay) is activated automatically when
//  settings.relayServer is non-nil (pass any non-empty value;
//  the actual relay host is always stun.dolphin-emu.org:6262).
//

import Foundation
import Combine
import PVNetplay
import ObjectiveC

// MARK: - Session context

/// Boxes role + settings so they can be stored via ObjC associated objects.
private final class DolphinNetplayContext: NSObject {
    let sessionID: UUID
    var role: NetplayRole
    var settings: NetplaySettings

    init(role: NetplayRole, settings: NetplaySettings) {
        self.sessionID = UUID()
        self.role      = role
        self.settings  = settings
    }
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
// emulation thread.  @unchecked Sendable is intentional — callers must not
// mutate netplay state concurrently.
extension PVDolphinCore: PVNetplayCapable {

    public var supportsNetplay: Bool { _bridge.dolphinNetplaySupported }

    public var netplayEngineName: String { "Dolphin" }

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

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _netplayQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NetplayError.bridgeNotReady)
                    return
                }

                var nsError: NSError?
                let ok: Bool

                switch role {
                case .host(let port):
                    ok = self._bridge.startNetplayHost(
                        onPort: port == 0 ? UInt16(settings.port) : port,
                        password: settings.password,
                        maxPlayers: settings.maxPlayers,
                        error: &nsError
                    )

                case .client(let host, let port):
                    // Dolphin traversal relay: non-nil relayServer triggers traversal mode.
                    let traversalCode: String? = settings.relayServer != nil ? host : nil
                    let directHost: String = settings.relayServer != nil ? "" : host
                    ok = self._bridge.joinNetplay(
                        host: directHost,
                        port: port == 0 ? UInt16(settings.port) : port,
                        traversalCode: traversalCode,
                        password: settings.password,
                        error: &nsError
                    )

                case .spectator(let host, let port):
                    // Dolphin has no spectator role; join as inactive client.
                    ok = self._bridge.joinNetplay(
                        host: host,
                        port: port == 0 ? UInt16(settings.port) : port,
                        traversalCode: nil,
                        password: settings.password,
                        error: &nsError
                    )
                }

                if ok {
                    self._netplayContext = DolphinNetplayContext(role: role, settings: settings)
                    continuation.resume()
                } else {
                    let reason = nsError?.localizedDescription ?? "Unknown Dolphin netplay error."
                    continuation.resume(throwing: NetplayError.connectionFailed(reason))
                }
            }
        }
    }

    public func stopNetplay() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            _netplayQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                self._bridge.stopNetplay()
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

    // MARK: - State

    public var netplayState: NetplayState {
        switch _bridge.dolphinNetplayStatus {
        case .idle:
            return .idle

        case .hosting:
            let ctx = _netplayContext
            // Use the effective port from the role (the port actually passed to the server),
            // falling back to settings.port only when the role port is 0.
            let effectivePort: UInt16
            if case .host(let rolePort) = ctx?.role, rolePort > 0 {
                effectivePort = rolePort
            } else {
                effectivePort = UInt16(ctx?.settings.port ?? 2626)
            }
            let room = NetplayRoom(
                id: ctx?.sessionID ?? UUID(),
                hostName: "Dolphin",
                gameName: "",
                gameHash: "",
                coreIdentifier: "com.provenance.dolphin",
                maxPlayers: ctx?.settings.maxPlayers ?? 4,
                currentPlayers: 1,
                isLAN: true,
                hostAddress: "0.0.0.0",
                port: effectivePort
            )
            return .hosting(room: room)

        case .connected:
            let ctx = _netplayContext
            let role = ctx?.role ?? .client(host: "0.0.0.0", port: 2626)
            let (hostAddr, port) = _resolvedHostPort(for: role, settings: ctx?.settings)
            let room = NetplayRoom(
                id: ctx?.sessionID ?? UUID(),
                hostName: "Dolphin",
                gameName: "",
                gameHash: "",
                coreIdentifier: "com.provenance.dolphin",
                maxPlayers: ctx?.settings.maxPlayers ?? 4,
                currentPlayers: 1,
                isLAN: true,
                hostAddress: hostAddr,
                port: port
            )
            // NOTE: frameDelay is stored in the session model for display purposes
            // but is not yet forwarded to Dolphin's netplay subsystem.
            // TODO: wire via _bridge.setDolphinFrameDelay(settings.frameDelay) once
            // the ObjC bridge exposes the Config::NETPLAY_INPUT_BUFFER_SIZE setter.
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
            _pollingCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    let state = self.netplayState
                    subject.send(state)
                    if case .idle = state {
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
        let defaultPort: UInt16 = settings?.port ?? 2626
        switch role {
        case .host(let rolePort):
            // Use the port explicitly provided in the role; fall back to settings.port.
            return ("127.0.0.1", rolePort > 0 ? rolePort : defaultPort)
        case .client(let host, let port):
            return (host, port == 0 ? defaultPort : port)
        case .spectator(let host, let port):
            return (host, port == 0 ? defaultPort : port)
        }
    }
}
