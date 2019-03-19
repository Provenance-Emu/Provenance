//
//  RoutingPackets.swift
//  sReto
//
//  Created by Julian Asamer on 23/08/14.
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

/** This enum represents the possible purposes of a direct connection - either to transmit routing information, or to be part of a user-requested routed connection. */
enum ConnectionPurpose: Int32 {
    case unknown = 0
    /** Used for connections that are used to transmit routing metadata. */
    case routingConnection = 1
    /** Used for user-requested connections that are routed. */
    case routedConnection = 2
}

/** 
* The LinkHandshake packet is the first packet exchanged over a direct connection, it is sent by the establishing peer. It contains that peer's identifier and 
* the purpose of the connection. It is used by the establishDirectConnection and handleDirectConnection methods in the Router class.
*/
struct LinkHandshake: Packet {
    let peerIdentifier: UUID
    let peerName: String
    let connectionPurpose: ConnectionPurpose

    static func getType() -> PacketType {
        return PacketType.linkHandshake
    }
    static func getMinimumLength() -> Int {
        return MemoryLayout<Int32>.size + MemoryLayout<UUID>.size*2 + MemoryLayout<ConnectionPurpose>.size
    }

    static func deserialize(_ data: DataReader) -> LinkHandshake? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getMinimumLength()) {
            return nil
        }

        let peerIdentifier = data.getUUID()
        let connectionPurpose = ConnectionPurpose(rawValue: data.getInteger())
        let peerName = String(data: data.getData(data.remaining()), encoding: String.Encoding.utf8)!

        return connectionPurpose.map { LinkHandshake(peerIdentifier: peerIdentifier, peerName: peerName, connectionPurpose: $0) }
    }

    func serialize() -> Data {
        let data = DataWriter(length: type(of: self).getMinimumLength())
        data.add(type(of: self).getType().rawValue)
        data.add(self.peerIdentifier)
        data.add(self.connectionPurpose.rawValue)
        data.add(self.peerName.data(using: String.Encoding.utf8)!)
        return data.getData() as Data
    }
}

/**
* The MulticastHandshake contains information relevant to establish a routed multi- or unicast connection.
* It is sent to each peer that is part of the route.
* It contains the identifier of the peer that originally established the peer, the set of destinations of the connection, and the direct connections that
* still need to be established structured as a tree (the nextHopTree). When a peer receives a MulticastHandshake, the nextHopTree is always rooted at that tree. 
* That node is expected to establish connections to all nodes that are its children in the nextHopTree.
*/
struct MulticastHandshake: Packet {
    static func getType() -> PacketType { return PacketType.multicastHandshake }
    static func getMinimumLength() -> Int { return MemoryLayout<Int32>.size + MemoryLayout<UUID>.size }

    let sourcePeerIdentifier: UUID
    let destinationIdentifiers: Set<UUID>
    let nextHopTree: Tree<UUID>

    static func deserialize(_ data: DataReader) -> MulticastHandshake? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getMinimumLength()) { return nil }

        let sourcePeerIdentifier = data.getUUID()
        let destinationsCount = Int(data.getInteger())

        if destinationsCount == 0 {
            log(.medium, error: "Invalid MulticastHandshake: no destinations specified.")
            return nil
        }
        if data.checkRemaining(destinationsCount * MemoryLayout<UUID>.size) == false {
            log(.medium, error: "Invalid MulticastHandshake: not enough data to read destinations.")
            return nil
        }
        var destinations: Set<UUID> = []
        for _ in 0..<destinationsCount { destinations += data.getUUID() }

        if let nextHopTree = deserializeNextHopTree(data) {
            return MulticastHandshake(sourcePeerIdentifier: sourcePeerIdentifier, destinationIdentifiers: destinations, nextHopTree: nextHopTree)
        } else {
            return nil
        }
    }

    func serialize() -> Data {
        let data = DataWriter(length: type(of: self).getMinimumLength() + MemoryLayout<Int32>.size + destinationIdentifiers.count * MemoryLayout<UUID>.size + nextHopTree.size * (MemoryLayout<Int32>.size + MemoryLayout<UUID>.size))
        data.add(type(of: self).getType().rawValue)
        data.add(self.sourcePeerIdentifier)
        data.add(Int32(self.destinationIdentifiers.count))
        for destination in self.destinationIdentifiers { data.add(destination) }

        serializeNextHopTree(data, nextHopTree: self.nextHopTree)

        return data.getData() as Data
    }

    static func deserializeNextHopTree(_ data: DataReader) -> Tree<UUID>? {
        if !data.checkRemaining(MemoryLayout<UUID>.size + MemoryLayout<Int32>.size) {
            log(.medium, error: "Invalid MulticastHandshake: not enough data to read tree.")
            return nil
        }

        let identifier = data.getUUID()
        let subtreeCount = data.getInteger()
        var subtrees: Set<Tree<UUID>> = []

        for _ in 0..<subtreeCount {
            if let child = deserializeNextHopTree(data) {
                subtrees += child
            } else {
                return nil
            }
        }

        return Tree(value: identifier, subtrees: subtrees)
    }

    func serializeNextHopTree(_ data: DataWriter, nextHopTree: Tree<UUID>) {
        data.add(nextHopTree.value)
        data.add(Int32(nextHopTree.subtrees.count))

        for subtree in nextHopTree.subtrees { serializeNextHopTree(data, nextHopTree: subtree) }
    }
}

/**
* This packet is used when establishing multicast connectinos to ensure that all destinations are actually connected.
* It only contains the sender's identifier and is sent by all peers once the hop connection establishment phase is complete.
*/
struct RoutedConnectionEstablishedConfirmationPacket: Packet {
    static func getType() -> PacketType { return PacketType.routedConnectionEstablishedConfirmation }
    static func getLength() -> Int { return MemoryLayout<Int32>.size + MemoryLayout<UUID>.size }

    let source: UUID

    static func deserialize(_ data: DataReader) -> RoutedConnectionEstablishedConfirmationPacket? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getLength()) { return nil }
        return RoutedConnectionEstablishedConfirmationPacket(source: data.getUUID())
    }

    func serialize() -> Data {
        let data = DataWriter(length: type(of: self).getLength())
        data.add(type(of: self).getType().rawValue)
        data.add(self.source)
        return data.getData() as Data
    }
}
