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
import ObjectiveC

// MARK: - Session context

/// Boxes the last-used role and settings so they can be stored via ObjC associated objects.
private final class MednafenNetplayContext: NSObject {
    let sessionID: UUID  // stable across netplayState polls — prevents UUID churn in the UI
    var role: NetplayRole
    var settings: NetplaySettings
    init(role: NetplayRole, settings: NetplaySettings) {
        self.sessionID = UUID()
        self.role = role
        self.settings = settings
    }
}

// MARK: - Associated-object keys

private enum AssocKeys {
    static var context    = "mdn_netplay_ctx"
    static var queue      = "mdn_netplay_queue"
    static var subject    = "mdn_netplay_subject"
    static var cancellable = "mdn_netplay_cancel"
}

// MARK: - PVNetplayCapable

// MednafenGameCore is ObjC-backed; its netplay state is mutated by Mednafen's
// run-loop thread.  @unchecked Sendable is intentional — callers must not
// mutate netplay state concurrently.
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

    /// Serial queue serialising all bridge netplay calls to avoid data races.
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
        // OBJC_ASSOCIATION_RETAIN (atomic) — sent from _netplayQueue, observed on main thread.
        objc_setAssociatedObject(self, &AssocKeys.subject, subject, .OBJC_ASSOCIATION_RETAIN)
        return subject
    }

    private var _pollingCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &AssocKeys.cancellable) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &AssocKeys.cancellable, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    // MARK: - Control

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard supportsNetplay else { throw NetplayError.unsupported }
        guard _bridge.mednafenNetplayStatus == .idle else { throw NetplayError.alreadyActive }

        let (host, port) = resolvedHostPort(for: role, settings: settings)
        let password = settings.password ?? ""

        // Dispatch bridge calls onto a dedicated serial queue to avoid racing
        // with the Mednafen run-loop thread that mutates engine globals.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _netplayQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                var nsError: NSError?
                let ok = self._bridge.netplayConnectToHost(host,
                                                           port: port,
                                                           nickname: settings.nickname,
                                                           password: password,
                                                           error: &nsError)
                if ok {
                    self._netplayContext = MednafenNetplayContext(role: role, settings: settings)
                    continuation.resume()
                } else {
                    let desc = nsError?.localizedDescription ?? "Mednafen connection failed."
                    continuation.resume(throwing: NetplayError.connectionFailed(desc))
                }
            }
        }
    }

    public func stopNetplay() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            _netplayQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self._bridge.netplayDisconnect()
                self._netplayContext = nil
                DispatchQueue.main.async {
                    self._stateSubject.send(.idle)
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - State

    public var netplayState: NetplayState {
        switch _bridge.mednafenNetplayStatus {
        case .idle:
            return .idle
        case .connected:
            let ctx = _netplayContext
            let role = ctx?.role ?? .client(host: "0.0.0.0", port: 4046)
            let (hostAddr, port) = resolvedHostPort(for: role, settings: ctx?.settings ?? .defaultLAN)
            let room = NetplayRoom(
                id: ctx?.sessionID ?? UUID(),
                hostName: "Mednafen",
                gameName: "",
                gameHash: "",
                coreIdentifier: "com.provenance.mednafen",
                maxPlayers: ctx?.settings.maxPlayers ?? 2,
                currentPlayers: ctx?.settings.maxPlayers ?? 2,
                isLAN: true,
                hostAddress: hostAddr,
                port: port
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

    /// A single shared publisher backed by one polling timer.
    ///
    /// Creates the timer on first access and caches both the subject and the
    /// `AnyCancellable` as associated objects so that subsequent accesses to
    /// this property return the same publisher without spawning extra timers.
    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        let subject = _stateSubject
        if _pollingCancellable == nil {
            _pollingCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    subject.send(self.netplayState)
                }
        }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Helpers

    /// Maps a `NetplayRole` to the `(host, port)` pair Mednafen should connect to.
    ///
    /// A port value of `0` is treated as "use Mednafen's default server port (4046)"
    /// rather than letting the OS assign an ephemeral port, since Mednafen's server
    /// always listens on a fixed port.
    private func resolvedHostPort(for role: NetplayRole,
                                  settings: NetplaySettings) -> (String, UInt16) {
        switch role {
        case .host(let port):
            // "Hosting" = connect to a local mednafen-server instance.
            return ("127.0.0.1", port == 0 ? 4046 : port)
        case .client(let host, let port):
            return (host, port == 0 ? 4046 : port)
        case .spectator(let host, let port):
            // Mednafen has no spectator role — join as a regular client.
            return (host, port == 0 ? 4046 : port)
        }
    }
}
