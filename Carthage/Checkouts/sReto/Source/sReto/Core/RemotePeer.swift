//
//  RemotePeer.swift
//  sReto
//
//  Created by Julian Asamer on 07/07/14.
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
* A RemotePeer represents another peer in the network.
*
* You do not construct RemotePeer instances yourself, they are provided to you by the LocalPeer.
*
* This class can be used to establish and accept connections to/from those peers.
* */
open class RemotePeer: NSObject {
    /** This peer's unique identifier. */
    open let identifier: UUID

    /** This peer's name. */
    open let name: String?

    /**
    * Set this property if you want to handle incoming connections on a per-peer basis.
    */
    open var onConnection: ConnectionClosure?

    /**
    * Establishes a connection to this peer.
    * 
    * @return A Connection to this peer.
    */
    open func connect() -> Connection {
        return self.localPeer.connect([self])
    }

    /**
    * Returns the UUID identifier as string to bridge to Objective-C Code
    * @return the UUID identifier as string
    */
    open func stringIdentifier() -> String {
        return self.identifier.UUIDString
    }

    // MARK: Internal

    /** The node representing this peer on the routing level */
    let node: Node
    /** The LocalPeer that created this peer */
    let localPeer: LocalPeer
    /** Stores all connections established by this peer */
    var connections: [UUID: PacketConnection] = [:]

    /**
    * Private initializer. See the class documentation about how to obtain RemotePeer instances.
    * @param node The node representing the the peer on the routing level.
    * @param localPeer The local peer that created this peer
    */
    init(node: Node, localPeer: LocalPeer, dispatchQueue: DispatchQueue) {
        self.node = node
        self.localPeer = localPeer
        self.identifier = node.identifier
        self.name = node.name
    }
}
