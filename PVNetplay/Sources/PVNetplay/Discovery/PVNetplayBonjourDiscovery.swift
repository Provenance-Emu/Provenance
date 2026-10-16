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
/// Discovers netplay rooms that Provenance hosts on the local network.
///
/// A hosting `NetpacketTransport` advertises its room under
/// `NetpacketTransport.bonjourServiceType`, with the game, core and player
/// count in the TXT record. This class browses for those advertisements and
/// publishes the rooms to observers.
///
/// Usage:
/// ```swift
/// let discovery = PVNetplayBonjourDiscovery()
/// discovery.startDiscovery()
/// // observe discovery.$rooms
/// ```
@MainActor
public final class PVNetplayBonjourDiscovery: NSObject, ObservableObject {
    /// The Bonjour service type hosts advertise under.
    private static let serviceType = NetpacketTransport.bonjourServiceType + "."

    @Published public private(set) var rooms: [NetplayRoom] = []
    @Published public private(set) var isSearching = false

    private var browser: NetServiceBrowser?
    private var pendingServices: [NetService] = []
    private var resolvedServices: [String: NetService] = [:]
    private var roomIDsByService: [String: UUID] = [:]

    // MARK: - Discovery Control

    /// Start scanning for rooms on the local network.
    public func startDiscovery() {
        guard !isSearching else { return }
        let b = NetServiceBrowser()
        b.delegate = self
        browser = b
        isSearching = true
        b.searchForServices(ofType: Self.serviceType, inDomain: "local.")
    }

    /// Stop scanning and clear discovered rooms.
    public func stopDiscovery() {
        browser?.stop()
        browser = nil
        pendingServices.removeAll()
        resolvedServices.values.forEach { $0.stopMonitoring() }
        resolvedServices.removeAll()
        roomIDsByService.removeAll()
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
        guard let hostAddress = NetplayRoomTXTRecord.preferredHostAddress(
            addresses: service.addresses ?? [],
            hostName: service.hostName
        ) else { return }

        let txtData = service.txtRecordData()
        let txtDict = txtData.map { NetService.dictionary(fromTXTRecord: $0) } ?? [:]
        let txt = txtDict.compactMapValues { String(data: $0, encoding: .utf8) }

        let room = NetplayRoomTXTRecord.room(
            fromTXT: txt,
            serviceName: service.name,
            hostAddress: hostAddress,
            port: service.port
        )

        // One room per advertised service: a TXT update replaces it.
        if let idx = rooms.firstIndex(where: { $0.id == room.id || $0.hostAddress == room.hostAddress && $0.port == room.port }) {
            rooms[idx] = room
        } else {
            rooms.append(room)
        }
        roomIDsByService[service.name] = room.id
    }

    private func removeRoom(forService service: NetService) {
        // The service passed to didRemove may be unresolved, so look the room
        // up by the instance name it was added under.
        guard let id = roomIDsByService.removeValue(forKey: service.name) else { return }
        rooms.removeAll { $0.id == id }
    }
}

// MARK: - NetServiceBrowserDelegate

extension PVNetplayBonjourDiscovery: @preconcurrency NetServiceBrowserDelegate {
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
        resolvedServices.removeValue(forKey: service.name)?.stopMonitoring()
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        isSearching = false
    }
}

// MARK: - NetServiceDelegate

extension PVNetplayBonjourDiscovery: @preconcurrency NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        pendingServices.removeAll { $0 === sender }
        resolvedServices[sender.name] = sender
        updateRoom(from: sender)
        // Without monitoring, didUpdateTXTRecord never fires and the player
        // count a host republishes is never seen.
        sender.startMonitoring()
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
