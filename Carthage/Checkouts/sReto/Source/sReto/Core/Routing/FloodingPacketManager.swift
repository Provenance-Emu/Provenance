//
//  FloodingPacketManager.swift
//  sReto
//
//  Created by Julian Asamer on 14/08/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

/**
* A FloodingPacket is a packet that floods any other packet through the network.
* The pair of sequenceNumber and originIdentifier are required to ensure that packets are not flooded indefinitely. See the FloodingPacketManager for more information.
*/
struct FloodingPacket: Packet {
    let sequenceNumber: Int32
    let originIdentifier: UUID
    let payload: Data

    static func getType() -> PacketType { return PacketType.floodPacket }
    static func getLength() -> Int { return MemoryLayout<PacketType>.size + MemoryLayout<Int32>.size + MemoryLayout<UUID>.size }

    static func deserialize(_ data: DataReader) -> FloodingPacket? {
        if !Packets.check(data: data, expectedType: self.getType(), minimumLength: self.getLength()) { return nil }
        return FloodingPacket(sequenceNumber: data.getInteger(), originIdentifier: data.getUUID(), payload: data.getData() as Data)
    }

    func serialize() -> Data {
        let data = DataWriter(length: type(of: self).getLength() + payload.count)
        data.add(type(of: self).getType().rawValue)
        data.add(self.sequenceNumber)
        data.add(self.originIdentifier)
        data.add(self.payload)
        return data.getData() as Data
    }
}

/**
* A function that can be called when a packet is received.
*/
typealias PacketHandlerFunction = (DataReader, PacketType) -> Void

/**
* The FloodingPacketManager implements the Flooding algorithm used to distribute packets through the network.
* When a packet is received, and it or a newer one has been seen before, it is discarded. This is accomplished by storing the last seen sequence number 
* for each sender.
* If the packet is new, it is forwarded to all direct neighbors of the local peer.
*/
class FloodingPacketManager: NSObject {
    /** The Router responsible for this flooding packet manager. */
    weak var router: Router?

    /** The next sequence number that will be used for packets sent from this peer. */
    var currentSequenceNumber: Int32 = 0
    /** The highest sequence number seen for each remote peer. */
    var sequenceNumbers: [UUID: Int32] = [:]
    /** The packet handlers registered with this flooding packet manager  */
    var packetHandlers: [PacketType: PacketHandlerFunction] = [:]

    /** Constructs a new FloodingPacketManager */
    init(router: Router) {
        self.router = router
    }

    /** Adds a packet handler for a given type. */
    func addPacketHandler(_ packetType: PacketType, handler: @escaping PacketHandlerFunction) {
        self.packetHandlers[packetType] = handler
    }

    /** Handles a received packet from a given source. If the packet is new, it is forwarded and handled, otherwise it is dismissed. */
    func handlePacket(_ sourceIdentifier: UUID, data: DataReader, packetType: PacketType) {
        let packet = FloodingPacket.deserialize(data)

        if let packet = packet {
            if let mostRecentSequenceNumber = self.sequenceNumbers[packet.originIdentifier] {
                if mostRecentSequenceNumber >= packet.sequenceNumber {
                    return
                }
            }

            self.sequenceNumbers[packet.originIdentifier] = packet.sequenceNumber

            for neighbor in router?.neighbors ?? [] {
                if neighbor.identifier == sourceIdentifier { continue }

                neighbor.sendPacket(packet)
            }

            if let packetType = PacketType(rawValue: DataReader(packet.payload).getInteger()) {
                if let packetHandler = self.packetHandlers[packetType] {
                    packetHandler(DataReader(packet.payload), packetType)
                } else {
                    log(.high, error: "Error in FloodingPacketManager: No packet handler for packet type \(packetType)")
                }
            } else {
                log(.high, error: "Error in FloodingPacketManager: Payload contains invalid packet type.")
            }
        }
    }

    /** Floods a new packet through the network. Increases the sequence number and sends the packet to all neighbors. */
    func floodPacket(_ packet: Packet) {
        if let router = self.router {
            let floodingPacket = FloodingPacket(sequenceNumber: self.currentSequenceNumber, originIdentifier: router.identifier, payload: packet.serialize() as Data)

            self.sequenceNumbers[router.identifier] = self.currentSequenceNumber
            self.currentSequenceNumber += 1

            for neighbor in router.neighbors {
                neighbor.sendPacket(floodingPacket)
            }
        }
    }
}
