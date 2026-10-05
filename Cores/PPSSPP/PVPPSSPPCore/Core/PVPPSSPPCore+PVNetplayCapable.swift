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
//   - Every player points at the same PRO Adhoc Server (TCP 27312); game data
//     then flows peer to peer at `gamePort + portOffset`, so all devices must
//     also share the port offset.
//   - host(port:)      → proAdhocServer = this device's LAN IP and PPSSPP's
//                        built-in server on. Never loopback: that is PPSSPP's
//                        single-machine mode and no other device could join.
//   - client(host:)    → proAdhocServer = the host's LAN IP.
//   - spectator(host:) → same as client (PPSSPP has no spectator concept).
//   - port parameter is unused — the adhoc server uses a fixed TCP port.
//   - The port offset and the built-in server are read only at boot, so
//     hosting restarts the game. The player then opens the game's own Ad Hoc
//     multiplayer menu on every device.
//

import Foundation
import Combine
import PVNetplay
import PVSettings
import ObjectiveC
import PVCoreObjCBridge

// MARK: - Session context storage

private final class PPSSPPNetplayContext {
    let role: NetplayRole
    let settings: NetplaySettings
    /// Stable IDs for the lifetime of this session so NetplayState equality
    /// checks (via UUID comparison) remain stable between timer ticks.
    let roomID: UUID
    let sessionID: UUID
    /// The effective adhoc server address used to start/join this session:
    /// this device's LAN IP for a host, otherwise the host or relay address.
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
        set { objc_setAssociatedObject(self, &PPSSPPNetplayContextKey.sessionContextKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
        let ctx = lastNetplayContext
        let port = UInt16(PVPPSSPPAdhocServerPort)
        switch _bridge.adhocStatus {
        case .idle:
            return .idle
        case .hosting:
            // The count is what the adhoc server has introduced to the game, so it
            // stays at 1 until the game's own ad hoc menu is open on both devices.
            let peers = max(0, _bridge.adhocPeerCount)
            let room = NetplayRoom.ppssppRoom(
                id: ctx?.roomID ?? UUID(),
                address: ctx?.effectiveServerAddress ?? "",
                port: port,
                currentPlayers: 1 + peers,
                context: ctx
            )
            return .hosting(room: room)
        case .connected:
            let host = ctx?.effectiveServerAddress ?? "0.0.0.0"
            let room = NetplayRoom.ppssppRoom(id: ctx?.roomID ?? UUID(), address: host, port: port, context: ctx)
            // Only claim a connection once the game's own ad hoc session is up.
            // Until then the device is configured but not yet playing.
            guard _bridge.adhocSessionConnected else { return .connecting(to: room) }
            // PPSSPP has no spectator concept, so .spectator joins as a client.
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

// MARK: - LAN address selection

/// Picks the address other devices on the Wi-Fi network would use to reach this one.
enum PPSSPPLANAddress {

    /// The best private IPv4 address in `addresses`, or nil when there is none.
    /// `NetplayLocalAddresses.current()` can also list cellular and VPN
    /// interfaces, so prefer the common home-router ranges in order.
    static func preferred(from addresses: [String]) -> String? {
        let ipv4 = addresses.filter { octets(of: $0) != nil }
        return ipv4.first { rank($0) == 0 } ?? ipv4.first { rank($0) == 1 } ?? ipv4.first { rank($0) == 2 }
    }

    /// The four octets of a dotted-quad IPv4 address, or nil when `text` is not one.
    static func octets(of text: String) -> [Int]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let values = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber) else { return nil }
            return Int(part)
        }
        return values.count == 4 && values.allSatisfy { (0...255).contains($0) } ? values : nil
    }

    /// 0 = 192.168/16, 1 = 172.16/12, 2 = 10/8, nil = not a private range.
    private static func rank(_ address: String) -> Int? {
        guard let o = octets(of: address) else { return nil }
        if o[0] == 192 && o[1] == 168 { return 0 }
        if o[0] == 172 && (16...31).contains(o[1]) { return 1 }
        if o[0] == 10 { return 2 }
        return nil
    }
}

// MARK: - PVNetplayCapable

extension PVPPSSPPCore: PVNetplayCapable {

    public var supportsNetplay: Bool { true }

    public var netplayEngineName: String { "PPSSPP AdHoc" }

    /// The port offset and the built-in server are read only when the game boots.
    public var netplayHostingRestartsGame: Bool { true }

    // MARK: Control

    /// Start a PPSSPP adhoc session.
    ///
    /// All mutations of g_Config must occur on the main thread (where the
    /// PPSSPP run loop executes).
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        do {
            let restart = try await MainActor.run { () -> Bool in
                var restartRequired = ObjCBool(false)
                let effectiveAddress: String
                let isHost: Bool
                switch role {
                case .host:
                    isHost = true
                    if let relay = settings.relayServer {
                        // WAN mode: connect to an external server rather than hosting locally.
                        effectiveAddress = relay
                        try _bridge.connect(toAdhocServer: relay, restartRequired: &restartRequired)
                    } else {
                        guard let lan = PPSSPPLANAddress.preferred(from: NetplayLocalAddresses.current()) else {
                            throw NetplayError.invalidSettings("Connect to a Wi-Fi network to host.")
                        }
                        effectiveAddress = lan
                        try _bridge.startAdhocLANHost(withAddress: lan, restartRequired: &restartRequired)
                    }
                case .client(let host, _), .spectator(let host, _):
                    // PPSSPP has no spectator concept — join as a regular client.
                    isHost = false
                    effectiveAddress = host.trimmingCharacters(in: .whitespaces)
                    try _bridge.connect(toAdhocServer: effectiveAddress, restartRequired: &restartRequired)
                }
                lastNetplayContext = PPSSPPNetplayContext(role: role, settings: settings, effectiveServerAddress: effectiveAddress)
                PVOSDNotification.postMessage(
                    Self.sessionMessage(isHost: isHost, address: effectiveAddress, restarting: restartRequired.boolValue),
                    type: .info,
                    duration: Self.sessionMessageDuration
                )
                return restartRequired.boolValue
            }
            if restart {
                // Reboots through setOptionValues, which applies the pending session.
                await MainActor.run { resetEmulation() }
            }
        } catch let error as NetplayError {
            throw error
        } catch {
            let reason = (error as NSError).localizedDescription
            throw NetplayError.connectionFailed(reason)
        }
    }

    /// Stop the current adhoc session.
    public func stopNetplay() async {
        await MainActor.run {
            if lastNetplayContext != nil {
                _bridge.stopAdhoc()
            }
            lastNetplayContext = nil
        }
    }

    // MARK: State

    public var netplayState: NetplayState { currentNetplayState }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        adhocStatePublisher
    }

    // MARK: Messages

    private static let sessionMessageDuration: TimeInterval = 8

    /// What to tell the player: the game itself still has to open its ad hoc menu.
    static func sessionMessage(isHost: Bool, address: String, restarting: Bool) -> String {
        let restartNote = restarting ? " The game is restarting to apply the network settings." : ""
        if isHost {
            return "Hosting on \(address).\(restartNote) Open the game's Ad Hoc multiplayer menu and create a game, then have the other player join."
        }
        return "Joining \(address).\(restartNote) Open the game's Ad Hoc multiplayer menu and join the host's game."
    }
}

// MARK: - NetplayRoom factory

private extension NetplayRoom {
    /// Builds a room descriptor from available PPSSPP context.
    static func ppssppRoom(
        id: UUID = UUID(),
        address: String,
        port: UInt16,
        currentPlayers: Int = 1,
        context: PPSSPPNetplayContext?
    ) -> NetplayRoom {
        let settings = context?.settings
        let nickname = settings.flatMap { $0.nickname.isEmpty ? nil : $0.nickname }
            ?? PVSettingsWrapper.resolvedPlayerUsername
        let isPasswordProtected = !(settings?.password?.isEmpty ?? true)
        // PPSSPP adhoc has no spectator concept — spectator falls back to joining
        // as a regular client.  Always advertise false so the UI does not offer
        // spectate flows that would silently connect as a player instead.
        let allowsSpectators = false
        return NetplayRoom(
            id: id,
            hostName: nickname,
            gameName: "",
            gameHash: "",
            coreIdentifier: CorePlist.pvCoreIdentifier,
            maxPlayers: settings?.maxPlayers ?? 2,
            currentPlayers: currentPlayers,
            isLAN: settings?.relayServer == nil,
            hostAddress: address,
            port: port,
            isPasswordProtected: isPasswordProtected,
            allowsSpectators: allowsSpectators,
            discoverySource: .manual
        )
    }
}
