//
//  Node.swift
//  sReto
//
//  Created by Julian Asamer on 26/07/14.
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
* The Node class represents the routing component of a remote peer. It stores all routing related information about that peer.
* Nodes are created and managed by a Router.
* 
* Nodes also forward FloodPackets to the FloodingPacketManager which handles those packets. These packets are used to transmit routing information.
*/
class Node: Hashable, PacketHandler {
    let linkStatePacketManager: FloodingPacketManager?

    /** The Router that created this Node object*/
    weak var router: Router!
    /** The Node's identifer*/
    let identifier: UUID
    /** The Node's name*/
    let name: String?
    /** The local peer's identifier. */
    let localIdentifier: UUID
    /** Addresses that allow to connect to this node directly. */
    var directAddresses: [Address] = []
    /** Whether this node is a neighbor of the local peer. */
    var isNeighbor: Bool {
        return reachableVia?.nextHop == self
    }
    /** Stores the PacketConnection used to transmit routing metadata. */
    var routingConnection: PacketConnection?
    var hashValue: Int {
        return identifier.hashValue
    }
    /** Whether a route to this node exists or not. */
    var isReachable: Bool {
        return reachableVia != nil
    }
    /** Of any pair of nodes that are neighbors, only one of them is responsible to establish the routingConnection, because only one is needed. This property 
    * is true for the node which is responsible for doing so. */
    var isResponsibleForEstablishingRoutingConnection: Bool {
        return self.identifier < self.localIdentifier
    }
    /** Returns the best direct address available to this node, based on the know Addresses' cost heuristic. */
    var bestAddress: Address? {
        return minimum(self.directAddresses, comparator: comparing { $0.cost })
    }
    /** If a connection should be established to this node, this property stores the next hop in the optimal route, as well as the total cost to the node. */
    var reachableVia: (nextHop: Node, cost: Int)?
    /** The next hop to use when establishing a connection to this node (if the optimal route should be used). */
    var nextHop: Node? {
        return reachableVia?.nextHop
    }

    /** Initializes a Node object */
    init(identifier: UUID, localIdentifier: UUID, name: String?, linkStatePacketManager: FloodingPacketManager?) {
        self.identifier = identifier
        self.localIdentifier = localIdentifier
        self.name = name
        self.linkStatePacketManager = linkStatePacketManager
    }
    /** Adds a direct address to this node */
    func addAddress(_ address: Address) {
        self.directAddresses.append(address)
    }
    /** Removes a direct address from this node */
    func removeAddress(_ address: Address) {
        self.directAddresses = self.directAddresses.filter { $0 !== address }
    }

    // MARK: Routing Connections (for routing information exchange)
    func establishRoutingConnection() {
        if !self.isResponsibleForEstablishingRoutingConnection {
            return
        }
        if self.routingConnection?.isConnected ?? false {
            return
        }

        self.router.establishDirectConnection(
            destination: self,
            purpose: .routingConnection,
            onConnection: {
                connection in
                let connectionIdentifier = randomUUID()
                let packetConnection = PacketConnection(
                    connection: connection,
                    connectionIdentifier: connectionIdentifier,
                    destinations: [self]
                )

                self.setupRoutingConnection(packetConnection)
                self.router.onNeighborReachable(self)
            },
            onFail: {
                log(.high, info: "Failed to establish routing connection.")
            }
        )
    }

    func handleRoutingConnection(_ connection: UnderlyingConnection) {
        let packetConnection = PacketConnection(connection: connection, connectionIdentifier: UUID_ZERO, destinations: [])
        self.setupRoutingConnection(packetConnection)
        self.router.onNeighborReachable(self)
    }

    func setupRoutingConnection(_ connection: PacketConnection) {
        self.routingConnection = connection
        connection.addDelegate(self)
        if connection.isConnected { self.underlyingConnectionDidConnect() }
    }

    func sendPacket(_ packet: Packet) {
        self.routingConnection?.write(packet)
    }

    // MARK: PacketConnection delegate
    let handledPacketTypes = [PacketType.floodPacket]
    func underlyingConnectionDidClose(_ error: AnyObject?) {
        self.router.onNeighborLost(self)
    }
    func willSwapUnderlyingConnection() {}
    func underlyingConnectionDidConnect() {}
    func didWriteAllPackets() {}
    func handlePacket(_ data: DataReader, type: PacketType) {
        self.linkStatePacketManager?.handlePacket(self.identifier, data: data, packetType: type)
    }
}

func == (lhs: Node, rhs: Node) -> Bool {
    return lhs.identifier == rhs.identifier
}
