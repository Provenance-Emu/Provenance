//
//  PVNetplayBonjourDiscovery.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@preconcurrency import Foundation
#if canImport(Combine)
import Combine
#endif

#if canImport(Combine)
/// Discovers RetroArch netplay rooms via Bonjour/NSNetService.
///
/// RetroArch compiled with `HAVE_NETPLAYDISCOVERY_NSNET` advertises rooms
/// under the `_retroarch._tcp.` service type. This class subscribes to those
/// advertisements and publishes discovered rooms to observers.
///
/// Usage:
/// ```swift
/// let discovery = PVNetplayBonjourDiscovery()
/// discovery.startDiscovery()
/// // observe discovery.$rooms
/// ```
@MainActor
public final class PVNetplayBonjourDiscovery: NSObject, ObservableObject {
    /// The Bonjour service type RetroArch advertises under.
    private static let retroArchServiceType = "_retroarch._tcp."

    @Published public private(set) var rooms: [NetplayRoom] = []
    @Published public private(set) var isSearching = false

    private var browser: NetServiceBrowser?
    private var pendingServices: [NetService] = []
    private var resolvedServices: [String: NetService] = [:]

    // MARK: - Discovery Control

    /// Start scanning for RetroArch rooms on the local network.
    public func startDiscovery() {
        guard !isSearching else { return }
        let b = NetServiceBrowser()
        b.delegate = self
        browser = b
        isSearching = true
        b.searchForServices(ofType: Self.retroArchServiceType, inDomain: "local.")
    }

    /// Stop scanning and clear discovered rooms.
    public func stopDiscovery() {
        browser?.stop()
        browser = nil
        pendingServices.removeAll()
        resolvedServices.removeAll()
        rooms.removeAll()
        isSearching = false
    }

    /// Remove stale rooms (last seen more than `threshold` seconds ago).
    public func removeStaleRooms(olderThan threshold: TimeInterval = 30) {
        let cutoff = Date().addingTimeInterval(-threshold)
        rooms = rooms.filter { $0.lastSeen > cutoff }
    }

    // MARK: - Private Helpers

    private func updateRoom(from service: NetService) {
        guard let hostName = service.hostName, !hostName.isEmpty else { return }

        let txtData = service.txtRecordData()
        let txtDict = txtData.map { NetService.dictionary(fromTXTRecord: $0) } ?? [:]

        func txtString(_ key: String) -> String? {
            guard let data = txtDict[key] else { return nil }
            return String(data: data, encoding: .utf8)
        }

        let gameName = txtString("game") ?? txtString("content") ?? "Unknown Game"
        let gameHash = txtString("hash") ?? ""
        let coreID = txtString("core") ?? ""
        let hostNickname = txtString("nickname") ?? service.name
        let maxPlayers = Int(txtString("maxPlayers") ?? "2") ?? 2
        let currentPlayers = Int(txtString("players") ?? "1") ?? 1
        let spectatorCount = Int(txtString("spectators") ?? "0") ?? 0
        let port = UInt16(service.port > 0 ? service.port : 55435)
        let hasPassword = txtString("password") == "1"
        let allowSpectators = txtString("allowSpectators") != "0"

        // Derive a stable UUID from the service name when no sessionId TXT record is present.
        // This prevents SwiftUI list identity churn on every TXT update.
        let sessionUUID: UUID
        if let sid = txtString("sessionId"), let parsed = UUID(uuidString: sid) {
            sessionUUID = parsed
        } else {
            // Derive a stable 16-byte identifier from the service name using
            // an XOR-fold over the UTF-8 bytes. This is deterministic across
            // launches (unlike Hasher, which is randomised per-process) and
            // safe (no buffer-size mismatch between an Int and a 16-byte UUID field).
            let nameBytes = Array(service.name.utf8)
            var bytes = [UInt8](repeating: 0, count: 16)
            for (i, byte) in nameBytes.enumerated() {
                bytes[i % 16] ^= byte
            }
            // Tag as UUID version 4 / variant 1 so the value is well-formed.
            bytes[6] = (bytes[6] & 0x0f) | 0x40
            bytes[8] = (bytes[8] & 0x3f) | 0x80
            let uuidTuple = (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
            sessionUUID = UUID(uuid: uuidTuple)
        }
        let room = NetplayRoom(
            id: sessionUUID,
            hostName: hostNickname,
            gameName: gameName,
            gameHash: gameHash,
            coreIdentifier: coreID,
            maxPlayers: maxPlayers,
            currentPlayers: currentPlayers,
            isLAN: true,
            hostAddress: hostName,
            port: port,
            isPasswordProtected: hasPassword,
            allowsSpectators: allowSpectators,
            spectatorCount: spectatorCount,
            discoverySource: .bonjour,
            lastSeen: Date()
        )

        if let idx = rooms.firstIndex(where: { $0.hostAddress == room.hostAddress && $0.port == room.port }) {
            rooms[idx] = room
        } else {
            rooms.append(room)
        }
    }

    private func removeRoom(forService service: NetService) {
        // Prefer the previously resolved hostName since the service passed to
        // netServiceBrowser(_:didRemove:) may be unresolved (hostName == nil).
        let resolved = resolvedServices[service.name]
        guard let hostName = resolved?.hostName ?? service.hostName else { return }
        let port = UInt16(service.port > 0 ? service.port : 55435)
        rooms.removeAll { $0.hostAddress == hostName && $0.port == port }
    }
}

// MARK: - NetServiceBrowserDelegate

extension PVNetplayBonjourDiscovery: NetServiceBrowserDelegate {
    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        isSearching = true
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isSearching = false
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        service.delegate = self
        pendingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        removeRoom(forService: service)
        pendingServices.removeAll { $0 === service }
        resolvedServices.removeValue(forKey: service.name)
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        isSearching = false
    }
}

// MARK: - NetServiceDelegate

extension PVNetplayBonjourDiscovery: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        pendingServices.removeAll { $0 === sender }
        resolvedServices[sender.name] = sender
        updateRoom(from: sender)
    }

    public func netService(
        _ sender: NetService,
        didNotResolve errorDict: [String: NSNumber]
    ) {
        pendingServices.removeAll { $0 === sender }
    }

    public func netService(
        _ sender: NetService,
        didUpdateTXTRecord data: Data
    ) {
        updateRoom(from: sender)
    }
}
#endif
