//
//  PVMelonDSCore+PVNetplayCapable.swift
//  PVMelonDS
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapts PVMelonDSCore to the PVNetplayCapable protocol so that
//  PVNetplayManager can drive melonDS DS local wireless sessions.
//
//  melonDS LocalMP model:
//    - All players on the same subnet call LocalMP::Init(port_base).
//    - There is no host/client distinction at the protocol level; DS wireless
//      uses peer-to-peer broadcast discovery just like real hardware.
//    - host(port:)      → Init(port_base: port) and act as group initiator.
//    - client(host:port:) → Init(port_base: port) and join the existing group.
//    - spectator(host:port:) → not supported; falls back to client join.
//    - WAN relay is not supported — LocalMP is LAN-only.
//

import Foundation
import Combine
import PVNetplay
import ObjectiveC

// UDP port base used by melonDS LocalMP — matches melonDS upstream default (7064).
private let kMelonDSLocalMPDefaultPortBase: UInt16 = 7064

// MARK: - Session context storage

private final class MelonDSNetplayContext {
    let role: NetplayRole
    let settings: NetplaySettings
    /// Stable IDs prevent UUID churn between timer ticks.
    let roomID: UUID
    let sessionID: UUID
    let portBase: UInt16
    init(role: NetplayRole, settings: NetplaySettings, portBase: UInt16) {
        self.role = role
        self.settings = settings
        self.portBase = portBase
        self.roomID = UUID()
        self.sessionID = UUID()
    }
}

private enum MelonDSNetplayContextKey {
    nonisolated(unsafe) static var key: UInt8 = 0
}

private extension PVMelonDSCore {
    var _netplayContext: MelonDSNetplayContext? {
        get { objc_getAssociatedObject(self, &MelonDSNetplayContextKey.key) as? MelonDSNetplayContext }
        set { objc_setAssociatedObject(self, &MelonDSNetplayContextKey.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - Publisher storage

private enum MelonDSStatePublisherKey {
    nonisolated(unsafe) static var key: UInt8 = 0
}

private extension PVMelonDSCore {
    /// A timer-driven publisher that polls LocalMP status once per second.
    var _localMPStatePublisher: AnyPublisher<NetplayState, Never> {
        if let existing = objc_getAssociatedObject(self, &MelonDSStatePublisherKey.key)
            as? AnyPublisher<NetplayState, Never> {
            return existing
        }
        let pub = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { [weak self] _ -> NetplayState in
                guard let self else { return .idle }
                return self._currentNetplayState
            }
            .removeDuplicates()
            .share()
            .eraseToAnyPublisher()
        objc_setAssociatedObject(self, &MelonDSStatePublisherKey.key, pub, .OBJC_ASSOCIATION_RETAIN)
        return pub
    }

    var _currentNetplayState: NetplayState {
        switch _bridge.localMPStatus {
        case .idle:
            return .idle
        case .active:
            let ctx = _netplayContext
            let portBase = ctx?.portBase ?? kMelonDSLocalMPDefaultPortBase
            let room = NetplayRoom.melonDSRoom(
                id: ctx?.roomID ?? UUID(),
                portBase: portBase,
                context: ctx
            )
            if case .host = ctx?.role {
                return .hosting(room: room)
            }
            let sessionRole = ctx?.role ?? .client(host: "0.0.0.0", port: portBase)
            let session = NetplaySession(
                id: ctx?.sessionID ?? UUID(),
                room: room,
                role: sessionRole,
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

extension PVMelonDSCore: PVNetplayCapable {

    public var supportsNetplay: Bool {
        PVMelonDSCoreBridge.localMPAvailable
    }

    public var netplayEngineName: String { "melonDS Local Wireless" }

    // MARK: Control

    /// Start a DS local wireless session.
    ///
    /// Both host and client call LocalMP::Init with the same port_base.
    /// All mutations are dispatched to the main thread where the melonDS
    /// run-loop executes.
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard supportsNetplay else { throw NetplayError.featureDisabled }
        guard _bridge.localMPStatus == .idle else { throw NetplayError.alreadyActive }

        // melonDS LocalMP does not support spectator mode; normalize spectators to clients.
        let effectiveRole: NetplayRole
        switch role {
        case .spectator(let host, let port):
            effectiveRole = .client(host: host, port: port)
        default:
            effectiveRole = role
        }

        let portBase: UInt16
        switch effectiveRole {
        case .host(let port):
            portBase = port == 0 ? kMelonDSLocalMPDefaultPortBase : port
        case .client(_, let port):
            portBase = port == 0 ? kMelonDSLocalMPDefaultPortBase : port
        default:
            portBase = kMelonDSLocalMPDefaultPortBase
        }

        do {
            try await MainActor.run {
                try _bridge.startLocalMP(withPortBase: portBase)
                _netplayContext = MelonDSNetplayContext(role: effectiveRole, settings: settings, portBase: portBase)
            }
        } catch {
            let reason = (error as NSError).localizedDescription
            throw NetplayError.connectionFailed(reason)
        }
    }

    /// Stop the current DS local wireless session.
    public func stopNetplay() async {
        await MainActor.run {
            _bridge.stopLocalMP()
            _netplayContext = nil
        }
    }

    // MARK: State

    public var netplayState: NetplayState { _currentNetplayState }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _localMPStatePublisher
    }
}

// MARK: - NetplayRoom factory

private extension NetplayRoom {
    static func melonDSRoom(
        id: UUID = UUID(),
        portBase: UInt16,
        context: MelonDSNetplayContext?
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }
        return NetplayRoom(
            id: id,
            hostName: nickname ?? "melonDS",
            gameName: "",
            gameHash: "",
            coreIdentifier: CorePlist.pvCoreIdentifier,
            maxPlayers: settings?.maxPlayers ?? 8,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "multicast",
            port: portBase,
            isPasswordProtected: false,
            allowsSpectators: false,
            discoverySource: .manual
        )
    }
}
