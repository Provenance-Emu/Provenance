//
//  PVNetplayBonjourDiscovery.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
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

    /// Stop scanning.
    public func stopDiscovery() {
        browser?.stop()
        browser = nil
        pendingServices.removeAll()
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

        let room = NetplayRoom(
            id: UUID(uuidString: txtString("sessionId") ?? "") ?? UUID(),
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
        guard let hostName = service.hostName else { return }
        let port = UInt16(service.port > 0 ? service.port : 55435)
        rooms.removeAll { $0.hostAddress == hostName && $0.port == port }
    }
}

// MARK: - NetServiceBrowserDelegate

extension PVNetplayBonjourDiscovery: NetServiceBrowserDelegate {
    public nonisolated func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in self.isSearching = true }
    }

    public nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in self.isSearching = false }
    }

    public nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        service.delegate = self
        Task { @MainActor in
            self.pendingServices.append(service)
            service.resolve(withTimeout: 5.0)
        }
    }

    public nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        Task { @MainActor in
            self.removeRoom(forService: service)
            self.pendingServices.removeAll { $0 === service }
            self.resolvedServices.removeValue(forKey: service.name)
        }
    }

    public nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        Task { @MainActor in self.isSearching = false }
    }
}

// MARK: - NetServiceDelegate

extension PVNetplayBonjourDiscovery: NetServiceDelegate {
    public nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            self.resolvedServices[sender.name] = sender
            self.updateRoom(from: sender)
        }
    }

    public nonisolated func netService(
        _ sender: NetService,
        didNotResolve errorDict: [String: NSNumber]
    ) {
        Task { @MainActor in
            self.pendingServices.removeAll { $0 === sender }
        }
    }

    public nonisolated func netService(
        _ sender: NetService,
        didUpdateTXTRecord data: Data
    ) {
        Task { @MainActor in self.updateRoom(from: sender) }
    }
}
#endif
