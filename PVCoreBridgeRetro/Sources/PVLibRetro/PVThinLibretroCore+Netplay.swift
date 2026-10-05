//
//  PVThinLibretroCore+Netplay.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Netplay for thin libretro cores that implement the netpacket interface
//  (RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE, env 78), such as gpSP (GBA
//  link cable) and melonDS DS (DS local wireless). The core exchanges its
//  own packets with other players; PVNetplay's NetpacketTransport carries
//  them, and PVThinLibretroFrontend hands them to the core on the emulation
//  thread.
//
//  Cores without that interface have no netplay on the thin wrapper:
//  RetroArch's rollback netplay needs the RetroArch runtime.
//

import Combine
import Foundation
import PVCoreBridge
import PVLogging
import PVNetplay

// MARK: - PVNetpacketCapable conformance

extension PVThinLibretroCore: PVNetpacketCapable {

    /// Whether the loaded core registered a netpacket callback via env 78.
    var hasNetpacketInterface: Bool {
        _bridge.hasNetpacketInterface
    }

    /// The protocol_version string from the core's callback, or nil.
    var netpacketProtocolVersion: String? {
        _bridge.netpacketProtocolVersion
    }
}

// MARK: - PVNetplayCapable conformance

extension PVThinLibretroCore: PVNetplayCapable {

    /// Netplay is supported when the core registered a netpacket callback.
    var supportsNetplay: Bool {
        hasNetpacketInterface
    }

    /// Human-readable name of the netplay engine powering this core.
    var netplayEngineName: String { "Netpacket" }

    /// Start hosting or join a host. Netpacket sessions have players only, so
    /// spectating is unsupported.
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard hasNetpacketInterface else { throw NetplayError.unsupported }
        guard _netpacketTransport == nil else { throw NetplayError.alreadyActive }

        let transportRole: NetpacketTransport.Role
        switch role {
        case .host(let port):
            transportRole = .host(port: port)
        case .client(let host, let port):
            transportRole = .client(host: host, port: port)
        case .spectator:
            throw NetplayError.invalidSettings("This game can't be watched as a spectator. Join as a player instead.")
        }

        let transport = NetpacketTransport(
            role: transportRole,
            protocolVersion: netpacketCompatibilityVersion,
            maxClients: max(settings.maxPlayers - 1, 1)
        )
        _netpacketTransport = transport
        let bridge = _bridge
        let room = makeNetplayRoom(role: role, settings: settings)
        if case .host = transportRole {
            transport.bonjourAdvertisement = (
                name: Self.bonjourInstanceName("\(room.hostName) — \(room.gameName)"),
                txtRecord: [
                    "sessionId": room.id.uuidString,
                    "nickname": room.hostName,
                    "game": room.gameName,
                    "core": room.coreIdentifier,
                    "maxPlayers": String(room.maxPlayers),
                    "allowSpectators": "0"
                ]
            )
        }

        transport.onPacket = { data, clientID in
            bridge.enqueueNetpacketData(data, fromClient: clientID)
        }
        // A client starts the core as soon as the host assigns its ID, before
        // the transport delivers the first packet, so none is dropped.
        transport.onWelcomed = { clientID in
            ILOG("ThinCore netplay: joined as client \(clientID)")
            bridge.startNetpacketSession(withClientID: clientID)
        }
        transport.onPeerConnected = { [weak self, weak transport] clientID in
            bridge.netpacketPeerConnected(clientID)
            self?.publishHostedRoom(room, peerCount: transport?.connectedPeerIDs.count ?? 0)
        }
        transport.onPeerDisconnected = { [weak self, weak transport] clientID in
            bridge.netpacketPeerDisconnected(clientID)
            self?.publishHostedRoom(room, peerCount: transport?.connectedPeerIDs.count ?? 0)
        }
        transport.onSessionEnded = { [weak self] error in
            WLOG("ThinCore netplay: session ended — \(error.localizedDescription)")
            self?.endNetplaySession(reason: error == .hostClosed ? .hostClosed : .networkError)
        }
        bridge.netpacketSendBlock = { [weak transport] flags, buf, len, clientID in
            guard let transport else { return }
            transport.send(data: Data(bytes: buf, count: len), to: clientID, flags: flags)
        }
        bridge.netpacketRejectPeerBlock = { [weak transport] clientID in
            transport?.disconnectPeer(clientID)
        }

        // The host is client 0 and starts before anyone can connect, so the
        // core sees `start` before any `connected`. A client only learns its
        // ID from the host's welcome.
        if case .host = transportRole {
            bridge.startNetpacketSession(withClientID: NetpacketTransport.hostID)
        }

        do {
            try await transport.start()
        } catch {
            endNetplaySession(reason: nil)
            throw NetplayError.connectionFailed(error.localizedDescription)
        }

        switch transportRole {
        case .host:
            publishHostedRoom(room, peerCount: 0)
        case .client:
            updateNetplayState(.connected(session: NetplaySession(
                room: room,
                role: role,
                peers: [],
                frameDelay: 0,
                isRollbackEnabled: false
            )))
        }
    }

    /// Stop the active netplay session.
    func stopNetplay() async {
        endNetplaySession(reason: nil)
    }

    /// The current netplay state.
    var netplayState: NetplayState {
        _netplayStateSubject.value
    }

    #if canImport(Combine)
    /// Publisher for netplay state changes.
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _netplayStateSubject.eraseToAnyPublisher()
    }
    #endif
}

// MARK: - Session helpers

extension PVThinLibretroCore {

    /// What peers must agree on: the core's netpacket protocol version, or
    /// its name and version when it doesn't declare one (as RetroArch does).
    var netpacketCompatibilityVersion: String {
        if let version = netpacketProtocolVersion, !version.isEmpty {
            return version
        }
        let info = _bridge.systemInfo
        return "\(Self.string(fromCField: info.library_name)) \(Self.string(fromCField: info.library_version))"
    }

    /// `name` cut to Bonjour's 63-byte instance-name limit without splitting a character.
    static func bonjourInstanceName(_ name: String) -> String {
        var result = ""
        for character in name {
            guard result.utf8.count + String(character).utf8.count <= 63 else { break }
            result.append(character)
        }
        return result
    }

    /// A NUL-terminated C `char[N]` field (imported as a tuple) as a String.
    private static func string<T>(fromCField field: T) -> String {
        withUnsafeBytes(of: field) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }

    /// Tears the session down: no transport callback fires after this, and the
    /// core gets `stop` on its next frame (or when emulation stops).
    func endNetplaySession(reason: DisconnectReason?) {
        _netpacketTransport?.stop()
        _netpacketTransport = nil
        _bridge.stopNetpacketSession()
        _bridge.netpacketSendBlock = nil
        _bridge.netpacketRejectPeerBlock = nil
        updateNetplayState(reason.map { .disconnected(reason: $0) } ?? .idle)
    }

    private func makeNetplayRoom(role: NetplayRole, settings: NetplaySettings) -> NetplayRoom {
        let gameName = _bridge.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? ""
        let (address, port): (String, UInt16)
        switch role {
        case .host(let hostPort): (address, port) = ("0.0.0.0", hostPort)
        case .client(let host, let hostPort), .spectator(let host, let hostPort): (address, port) = (host, hostPort)
        }
        return NetplayRoom(
            hostName: settings.nickname.isEmpty ? "Provenance" : settings.nickname,
            gameName: gameName,
            gameHash: "",
            coreIdentifier: coreIdentifier ?? "",
            maxPlayers: settings.maxPlayers,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: address,
            port: port,
            allowsSpectators: false,
            discoverySource: .netpacket
        )
    }

    private func publishHostedRoom(_ room: NetplayRoom, peerCount: Int) {
        updateNetplayState(.hosting(room: NetplayRoom(
            id: room.id,
            hostName: room.hostName,
            gameName: room.gameName,
            gameHash: room.gameHash,
            coreIdentifier: room.coreIdentifier,
            maxPlayers: room.maxPlayers,
            currentPlayers: 1 + peerCount,
            isLAN: room.isLAN,
            hostAddress: room.hostAddress,
            port: room.port,
            allowsSpectators: false,
            discoverySource: .netpacket
        )))
    }
}

// MARK: - Backing storage

extension PVThinLibretroCore {

    /// The active netpacket transport, or nil when no session is running.
    var _netpacketTransport: NetpacketTransport? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.transport) as? NetpacketTransport }
        set { objc_setAssociatedObject(self, &AssociatedKeys.transport, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Combine subject for netplay state updates (also serves as source of truth).
    /// Created under a lock: the manager actor and the main thread can both
    /// reach it first.
    var _netplayStateSubject: CurrentValueSubject<NetplayState, Never> {
        AssociatedKeys.stateSubjectLock.lock()
        defer { AssociatedKeys.stateSubjectLock.unlock() }
        if let existing = objc_getAssociatedObject(self, &AssociatedKeys.stateSubject)
            as? CurrentValueSubject<NetplayState, Never> {
            return existing
        }
        let subject = CurrentValueSubject<NetplayState, Never>(.idle)
        objc_setAssociatedObject(self, &AssociatedKeys.stateSubject, subject, .OBJC_ASSOCIATION_RETAIN)
        return subject
    }

    /// Publish a netplay state change.
    func updateNetplayState(_ state: NetplayState) {
        _netplayStateSubject.send(state)
    }
}

// MARK: - Private helpers

/// Associated object keys for netplay state stored on PVThinLibretroCore.
private enum AssociatedKeys {
    nonisolated(unsafe) static var transport = 0
    nonisolated(unsafe) static var stateSubject = 0
    static let stateSubjectLock = NSLock()
}
