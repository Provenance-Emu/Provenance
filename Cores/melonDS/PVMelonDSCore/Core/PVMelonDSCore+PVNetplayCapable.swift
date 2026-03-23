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

// UDP port base used by melonDS LocalMP — sourced from ObjC constant to avoid drift.
// Matches the melonDS upstream default of 7064.
private let kMelonDSLocalMPDefaultPortBase: UInt16 = PVMelonDSLocalMPDefaultPortBase

// The global Provenance/RetroArch netplay default port is treated as "unspecified"
// for melonDS LocalMP. Using it would collide with RetroArch sessions; when it is
// the incoming port we fall back to the melonDS default (7064).
// Derived from NetplaySettings.defaultLAN.port to avoid drift if the default changes.
private let kProvenanceGlobalNetplayDefaultPort: UInt16 = NetplaySettings.defaultLAN.port

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
            // _netplayContext should always be set when LocalMP is active because
            // startNetplay stores the context atomically with Init on the main actor.
            // Guard here to prevent UUID churn if state ever desyncs.
            guard let ctx = _netplayContext else { return .idle }
            let room = NetplayRoom.melonDSRoom(
                id: ctx.roomID,
                portBase: ctx.portBase,
                context: ctx
            )
            if case .host = ctx.role {
                return .hosting(room: room)
            }
            let session = NetplaySession(
                id: ctx.sessionID,
                room: room,
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
    ///
    /// - Important: melonDS LocalMP uses UDP multicast on the local subnet.
    ///   The app target must include the `com.apple.developer.networking.multicast`
    ///   entitlement (requires Apple approval) for multicast traffic to work
    ///   reliably on-device. Without it, discovery may silently fail at runtime
    ///   even when all other conditions are met.
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard supportsNetplay else { throw NetplayError.unsupported }

        // melonDS LocalMP does not support spectator mode; normalize spectators to clients.
        let effectiveRole: NetplayRole
        switch role {
        case .spectator(let host, let port):
            effectiveRole = .client(host: host, port: port)
        default:
            effectiveRole = role
        }

        // Resolve the port base: treat 0 and the global Provenance netplay default
        // (kProvenanceGlobalNetplayDefaultPort) as "unspecified" so melonDS always
        // uses its own default (7064) unless the user explicitly configured a
        // melonDS-specific port. This avoids collision with RetroArch sessions.
        func resolvedPortBase(_ port: UInt16) -> UInt16 {
            (port == 0 || port == kProvenanceGlobalNetplayDefaultPort)
                ? kMelonDSLocalMPDefaultPortBase
                : port
        }

        let portBase: UInt16
        switch effectiveRole {
        case .host(let port):
            portBase = resolvedPortBase(port)
        case .client(_, let port):
            portBase = resolvedPortBase(port)
        default:
            portBase = kMelonDSLocalMPDefaultPortBase
        }

        // Perform both the idle-guard and the start/store atomically on the main
        // actor so there is no data race against bridge state mutations.
        try await MainActor.run {
            guard _bridge.localMPStatus == .idle else { throw NetplayError.alreadyActive }
            do {
                try _bridge.startLocalMP(withPortBase: portBase)
            } catch {
                throw NetplayError.connectionFailed((error as NSError).localizedDescription)
            }
            _netplayContext = MelonDSNetplayContext(role: effectiveRole, settings: settings, portBase: portBase)
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
