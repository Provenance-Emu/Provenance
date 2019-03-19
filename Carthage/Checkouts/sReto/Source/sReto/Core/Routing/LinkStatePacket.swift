//
//  LinkStatePacket.swift
//  sReto
//
//  Created by Julian Asamer on 15/08/14.
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
* A LinkState packet represents a peer's link state, i.e. a list of all of it's neighbors and the cost associated with reaching them.
*/
struct LinkStatePacket: Packet {
    /** The identifier of the peer that generated the packet. */
    let peerIdentifier: UUID
    /** A list of identifier/cost pairs for each of the peer's neighbors. */
    let neighbors: [(identifier: UUID, cost: Int32)]

    static func getType() -> PacketType { return PacketType.linkState }
    static func getLength() -> Int { return MemoryLayout<PacketType>.size + MemoryLayout<UUID>.size }

    static func deserialize(_ data: DataReader) -> LinkStatePacket? {
        if !Packets.check(data: data, expectedType: self.getType(), minimumLength: self.getLength()) { return nil }

        let peerIdentifier = data.getUUID()
        var neighbors: [(identifier: UUID, cost: Int32)] = []
        let neighborCount: Int = Int(data.getInteger())

        if !data.checkRemaining(neighborCount * (MemoryLayout<UUID>.size + MemoryLayout<Int32>.size)) {
            log(.high, error: "not enough data remaining in LinkStatePacket.")
            return nil
        }

        for _ in 0..<neighborCount {
            neighbors.append((identifier: data.getUUID(), cost: data.getInteger()))
        }

        return LinkStatePacket(peerIdentifier: peerIdentifier, neighbors: neighbors)
    }

    func serialize() -> Data {
        let data = DataWriter(length: type(of: self).getLength() + self.neighbors.count * (MemoryLayout<UUID>.size + MemoryLayout<Int32>.size))
        data.add(type(of: self).getType().rawValue)
        data.add(self.peerIdentifier)
        data.add(Int32(self.neighbors.count))

        for (identifier, cost) in self.neighbors {
            data.add(identifier)
            data.add(cost)
        }

        return data.getData() as Data
    }
}
