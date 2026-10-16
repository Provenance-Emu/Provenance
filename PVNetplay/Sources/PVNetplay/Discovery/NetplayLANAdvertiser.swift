//
//  NetplayLANAdvertiser.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Publishes a hosted room on the local network so `PVNetplayBonjourDiscovery`
/// finds it.
///
/// `PVNetplayManager` uses this for every core whose netplay engine opens its
/// own socket (Dolphin's ENet server, mGBA, Mednafen, PPSSPP ad hoc). Those
/// engines can't share a Network.framework listener, so the room is published
/// as a plain DNS-SD record pointing at the engine's port.
public protocol NetplayRoomAdvertising: AnyObject, Sendable {
    /// Publish `room`, or replace the record already published.
    @MainActor func advertise(_ room: NetplayRoom)
    /// Withdraw the published record. Safe to call when nothing is published.
    @MainActor func withdraw()
}

#if canImport(Darwin)
import os.log

/// `NetplayRoomAdvertising` over `NetService`, the same API the browser uses.
///
/// `@unchecked Sendable`: its state is touched only from the `@MainActor`
/// methods, so it can be created off the main actor (`PVNetplayManager.shared`).
public final class NetServiceRoomAdvertiser: NSObject, NetplayRoomAdvertising, @unchecked Sendable {
    private var service: NetService?
    private var publishedName: String?
    private var publishedPort: UInt16?

    public override init() {
        super.init()
    }

    @MainActor
    public func advertise(_ room: NetplayRoom) {
        let name = NetplayRoomTXTRecord.instanceName(for: room)
        let txt = NetplayRoomTXTRecord.txtRecord(for: room).mapValues { Data($0.utf8) }
        let txtData = NetService.data(fromTXTRecord: txt)

        // Same name and port: refresh the TXT record (player count) in place.
        if let service, publishedName == name, publishedPort == room.port {
            service.setTXTRecord(txtData)
            return
        }

        withdraw()
        let newService = NetService(
            domain: "local.",
            type: NetpacketTransport.bonjourServiceType + ".",
            name: name,
            port: Int32(room.port)
        )
        newService.delegate = self
        newService.setTXTRecord(txtData)
        // No listening: the core's own engine owns the port.
        newService.publish()
        service = newService
        publishedName = name
        publishedPort = room.port
    }

    @MainActor
    public func withdraw() {
        service?.stop()
        service = nil
        publishedName = nil
        publishedPort = nil
    }
}

extension NetServiceRoomAdvertiser: NetServiceDelegate {
    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        // Most often the Local Network permission was refused.
        os_log(.error, "Netplay: could not publish the room on the local network: %{public}@", errorDict.description)
    }
}
#endif
