//
//  PVThinLibretroCore+Netplay.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Conforms PVThinLibretroCore to PVNetpacketCapable (which extends
//  PVNetplayCapable) by bridging PVNetplay's NetpacketTransport to the
//  ObjC netpacket session API on PVThinLibretroFrontend.
//
//  The transport handles Network.framework connections; the ObjC bridge
//  stores the core's retro_netpacket_callback and provides the static C
//  send_fn / poll_receive_fn that the core calls on the emulation thread.
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

    /// Start a netplay session using the netpacket transport.
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        guard hasNetpacketInterface else { throw NetplayError.unsupported }
        guard _netpacketTransport == nil else { throw NetplayError.alreadyActive }

        let transportRole: NetpacketTransport.Role
        switch role {
        case .host(let port):
            transportRole = .host(port: port)
        case .client(let host, let port):
            transportRole = .client(host: host, port: port)
        case .spectator(let host, let port):
            transportRole = .client(host: host, port: port)
        }

        let transport = NetpacketTransport(role: transportRole)
        _netpacketTransport = transport

        transport.onPeerConnected = { [weak self] clientID in
            self?._bridge.netpacketPeerConnected(clientID)
        }
        transport.onPeerDisconnected = { [weak self] clientID in
            self?._bridge.netpacketPeerDisconnected(clientID)
        }

        _bridge.netpacketSendBlock = { [weak transport] flags, buf, len, clientID in
            guard let transport, let buf else { return }
            let data = Data(bytes: buf, count: len)
            transport.send(data: data, to: clientID, flags: flags)
        }

        do {
            try await transport.start()
        } catch {
            _netpacketTransport = nil
            _bridge.netpacketSendBlock = nil
            throw NetplayError.connectionFailed(error.localizedDescription)
        }

        _bridge.startNetpacketSession(withClientID: transport.localClientID)

        let room = NetplayRoom(
            hostName: settings.nickname.isEmpty ? "Local Host" : settings.nickname,
            gameName: "",
            gameHash: "",
            coreIdentifier: "",
            maxPlayers: settings.maxPlayers,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "0.0.0.0",
            port: settings.port,
            discoverySource: .netpacket
        )

        updateNetplayState(.hosting(room: room))
    }

    /// Stop the active netplay session.
    func stopNetplay() async {
        _bridge.stopNetpacketSession()
        _netpacketTransport?.stop()
        _netpacketTransport = nil
        _bridge.netpacketSendBlock = nil
        updateNetplayState(.idle)
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

// MARK: - Backing storage

extension PVThinLibretroCore {

    /// The active netpacket transport, or nil when no session is running.
    var _netpacketTransport: NetpacketTransport? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.transport) as? NetpacketTransport }
        set { objc_setAssociatedObject(self, &AssociatedKeys.transport, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Combine subject for netplay state updates (also serves as source of truth).
    var _netplayStateSubject: CurrentValueSubject<NetplayState, Never> {
        if let existing = objc_getAssociatedObject(self, &AssociatedKeys.stateSubject)
            as? CurrentValueSubject<NetplayState, Never> {
            return existing
        }
        let subject = CurrentValueSubject<NetplayState, Never>(.idle)
        objc_setAssociatedObject(self, &AssociatedKeys.stateSubject, subject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return subject
    }

    /// Update netplay state in both the subject (for Combine subscribers) and the
    /// current value (for synchronous reads via `netplayState`).
    func updateNetplayState(_ state: NetplayState) {
        _netplayStateSubject.send(state)
    }
}

// MARK: - Private helpers

/// Associated object keys for netplay state stored on PVThinLibretroCore.
private enum AssociatedKeys {
    nonisolated(unsafe) static var transport = 0
    nonisolated(unsafe) static var stateSubject = 0
}
