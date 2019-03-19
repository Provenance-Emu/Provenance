//
//  LocalPeer.swift
//  sReto
//
//  Created by Julian Asamer on 04/07/14.
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

#if os( iOS)
    import UIKit
#endif

/** Used to notify about discovered peers. */
public typealias PeerDiscoveredClosure = (_ peer: RemotePeer) -> Void
/** Used to notify about removed peers. */
public typealias PeerRemovedClosure = (_ peer: RemotePeer) -> Void
/** Used to notify about incoming connections peers. */
public typealias ConnectionClosure = (_ peer: RemotePeer, _ connection: Connection) -> Void

/**
* A LocalPeer advertises the local peer in the network and browses for other peers.
*
* It requires one or more Modules to accomplish this. Two Modules that come with Reto are the WlanModule and the RemoteP2P module.
*
* The LocalPeer can also be used to establish multicast connections to multiple other peers.
*/
open class LocalPeer: NSObject, ConnectionManager, RouterHandler {
    /** This peer's name. If not specified in the constructor, it has a the device name. */
    open let name: String
    /** This peer's unique identifier. If not specified in the constructor, it has a random value. */
    open let identifier: UUID
    /** The dispatch queue used to execute all networking operations and callbacks */
    open let dispatchQueue: DispatchQueue
    /** The set of peers currently reachable */
    open var peers: Set<RemotePeer> {
        return Set(knownPeers.values)
    }

    static var deviceName: String {
        #if os( iOS)
            return UIDevice.current.name
        #else
            return Host.current().localizedName!
        #endif
    }

    /**
    * Constructs a new LocalPeer object. A random identifier will be used for the LocalPeer.
    * Note that a LocalPeer is not functional without modules. You can add modules later with the addModule method.
    * The main dispatch queue is used for all networking code.
    */
    public convenience override init() {
        self.init(name: LocalPeer.deviceName, identifier: randomUUID(), modules: [], dispatchQueue: DispatchQueue.main)
    }

    /**
    * Constructs a new LocalPeer object. A random identifier will be used for the LocalPeer.
    * Note that a LocalPeer is not functional without modules. You can add modules later with the addModule method.
    *
    * @param dispatchQueue The dispatchQueue used to run all networking code with. The dispatchQueue can be used to specifiy the thread that should be used.
    */
    public convenience init(dispatchQueue: DispatchQueue) {
        self.init(name: LocalPeer.deviceName, identifier: randomUUID(), modules: [], dispatchQueue: dispatchQueue)
    }
    /**
    * Constructs a new LocalPeer object.
    *
    * @param modules An array of modules used for the underlying networking functionality. For example: @see WlanModule, @see RemoteP2PModule.
    * @param dispatchQueue The dispatchQueue used to run all networking code with. The dispatchQueue can be used to specifiy the thread that should be used.
    */
    public convenience init(modules: [Module], dispatchQueue: DispatchQueue) {
        self.init(name: LocalPeer.deviceName, identifier: randomUUID(), modules: modules, dispatchQueue: dispatchQueue)
    }

    /**
     * Constructs a new LocalPeer object.
     *
     * @param name The name used for the peer
     * @param modules An array of modules used for the underlying networking functionality. For example: @see WlanModule, @see RemoteP2PModule.
     * @param dispatchQueue The dispatchQueue used to run all networking code with. The dispatchQueue can be used to specifiy the thread that should be used.
     */
    public convenience init(name: String, modules: [Module], dispatchQueue: DispatchQueue) {
        self.init(name: name, identifier: randomUUID(), modules: modules, dispatchQueue: dispatchQueue)
    }

    /**
     * Constructs a new LocalPeer object. A random identifier will be used for the LocalPeer.
     *
     * @param name The name used for the peer
     * @param localPeerIdentifier The identifier used for the peer
     * @param modules An array of modules used for the underlying networking functionality. For example: @see WlanModule, @see RemoteP2PModule.
     * @param dispatchQueue The dispatchQueue used to run all networking code with. The dispatchQueue can be used to specifiy the thread that should be used.
     */
    public init(name: String, identifier: UUID, modules: [Module], dispatchQueue: DispatchQueue) {
        self.name = name
        self.identifier = identifier
        self.router = DefaultRouter(localIdentifier: identifier, localName: name, dispatchQueue: dispatchQueue, modules: modules)
        self.dispatchQueue = dispatchQueue

        super.init()

        self.router.delegate = self
    }

    /**
    * Returns the UUID identifier as string to bridge to Objective-C Code
    * @return the UUID identifier as string
    */
    open func stringIdentifier() -> String {
        return self.identifier.UUIDString
    }

    /**
    * This method starts the local peer. This will advertise the local peer in the network and starts browsing for other peers.
    * You need to set the incomingConnectionBlock property of any discovered peers, otherwise you will not be able to handle incoming connections.
    *
    * @param onPeerDiscovered Called when a peer is discovered.
    * @param onPeerRemoved Called when a peer is removed.
    */
    open func start(onPeerDiscovered: @escaping PeerDiscoveredClosure, onPeerRemoved: @escaping PeerRemovedClosure) {
        self.onPeerDiscovered = onPeerDiscovered
        self.onPeerRemoved = onPeerRemoved

        self.startRouter()
    }
    /**
    * This method starts the local peer. This will advertise the local peer in the network, starts browsing for other peers, and accepts incoming connections.
    * @param onPeerDiscovered Called when a peer is discovered.
    * @param onPeerRemoved Called when a peer is removed.
    * @param onIncomingConnection Called when a connection is available. Call accept on the peer to accept the connection.
    */
    open func start(onPeerDiscovered: @escaping PeerDiscoveredClosure, onPeerRemoved: @escaping PeerRemovedClosure, onIncomingConnection: @escaping ConnectionClosure, displayName: String?) {
        self.onPeerDiscovered = onPeerDiscovered
        self.onPeerRemoved = onPeerRemoved
        self.onConnection = onIncomingConnection

        self.startRouter()
    }

    /*
    * Stops advertising and browsing.
    */
    open func stop() {
        self.router.stop()

        self.onPeerDiscovered = nil
        self.onPeerRemoved = nil
        self.onConnection = nil
    }
    /**
    * Add a module to this LocalPeer. The module will be started immediately if the LocalPeer is already started.
    * @param module The module that should be added.
    */
    open func addModule(_ module: Module) {
        self.router.addModule(module)
    }
    /**
    * Remove a module from this LocalPeer.
    * @param module The module that should be removed.
    */
    open func removeModule(_ module: Module) {
        self.router.addModule(module)
    }

    // MARK: Establishing multicast connections

    /**
    * Establishes a multicast connection to a set of peers. The connection can only be used to send data, not to receive data.
    * @param destinations The RemotePeers to establish a connection with.
    * @return A Connection object. It can be used to send data immediately (the transfers will be started once the connection was successfully established).
    */
    open func connect(_ destinations: Set<RemotePeer>) -> Connection {
        let destinations = Set(destinations.map { $0.node })
        let identifier = randomUUID()
        let packetConnection = PacketConnection(connection: nil, connectionIdentifier: identifier, destinations: destinations)

        self.establishedConnections[identifier] = packetConnection

        let transferConnection = Connection(packetConnection: packetConnection, localIdentifier: self.identifier, dispatchQueue: self.dispatchQueue, isConnectionEstablisher: true, connectionManager: self)
        transferConnection.reconnect()

        return transferConnection
    }

    // MARK: Internal and Private
    fileprivate var onPeerDiscovered: PeerDiscoveredClosure?
    fileprivate var onPeerRemoved: PeerRemovedClosure?
    var onConnection: ConnectionClosure?

    fileprivate let router: DefaultRouter
    fileprivate var knownPeers = [Node: RemotePeer]()
    fileprivate var establishedConnections = [UUID: PacketConnection]()
    fileprivate var incomingConnections = [UUID: PacketConnection]()

    fileprivate func startRouter() {
        if self.router.modules.count == 0 {
            log(.high, warning: "You started the LocalPeer, but it does not have any modules. It cannot function without modules. See the LocalPeer class documentation for more information.")
        }

        self.router.start()
    }

    fileprivate func providePeer(_ node: Node) -> RemotePeer {
        return self.knownPeers.getOrDefault(node, defaultValue: RemotePeer(node: node, localPeer: self, dispatchQueue: self.dispatchQueue))
    }

    /**
    * Called when ManagedConnectionHandshake was received, i.e. when all necessary information is available to deal with this connection.
    * If the corresponding PacketConnection already exists, its underlying connection is swapped. Otherwise, a new Connection is created.
    *
    * @param router The router which reported the connection
    * @param node The node which established the connection
    * @param connection The connection that was established
    * @param connectionIdentifier The identifier of the connection
    * */
    fileprivate func handleConnection(node: Node, connection: UnderlyingConnection, connectionIdentifier: UUID) {
        let needsToReportPeer = self.knownPeers[node] == nil

        let peer = self.providePeer(node)

        if needsToReportPeer {
            self.onPeerDiscovered?(peer)
        }

        if let packetConnection = peer.connections[connectionIdentifier] {
            packetConnection.swapUnderlyingConnection(connection)
        } else {
            self.createConnection(peer: peer, connection: connection, connectionIdentifier: connectionIdentifier)
        }
    }

    /**
    * Creates a new connection and calls the handling closure.
    */
    fileprivate func createConnection(peer: RemotePeer, connection: UnderlyingConnection, connectionIdentifier: UUID) {
        let packetConnection = PacketConnection(connection: connection, connectionIdentifier: connectionIdentifier, destinations: [peer.node])
        peer.connections[connectionIdentifier] = packetConnection
        self.incomingConnections[connectionIdentifier] = packetConnection

        let transferConnection = Connection(
            packetConnection: packetConnection,
            localIdentifier: self.identifier,
            dispatchQueue: self.dispatchQueue,
            isConnectionEstablisher: false,
            connectionManager: self
        )

        if let connectionClosure = peer.onConnection {
            connectionClosure(peer, transferConnection)
        } else if let connectionClosure = self.onConnection {
            connectionClosure(peer, transferConnection)
        } else {
            log(.high, warning: "An incoming connection was received, but onConnection is not set. Set it either in your LocalPeer instance (\(self)), or in the RemotePeer which established the connection (\(peer)).")
        }
    }

    // MARK: RouterDelegate
    internal func didFindNode(_ router: Router, node: Node) {
        if self.knownPeers[node] != nil {
            return
        }

        let peer = providePeer(node)

        self.onPeerDiscovered?(peer)
    }

    internal func didImproveRoute(_ router: Router, node: Node) {
        self.reconnect(self.providePeer(node))
    }

    internal func didLoseNode(_ router: Router, node: Node) {
        let peer = providePeer(node)
        self.knownPeers[node] = nil
        peer.onConnection = nil
        self.onPeerRemoved?(peer)
    }

    /**
    * Handles an incoming connection.
    *
    * @param router The router which reported the connection
    * @param node The node which established the connection
    * @param connection The connection that was established
    * */
    internal func handleConnection(_ router: Router, node: Node, connection: UnderlyingConnection) {
        log(.high, info: "Handling incoming connection...")
        _ = readSinglePacket(connection: connection, onPacket: { data in
            if let packet = ManagedConnectionHandshake.deserialize(data) {
                self.handleConnection(node: node, connection: connection, connectionIdentifier: packet.connectionIdentifier)
            } else {
                log(.low, info: "Expected ManagedConnectionHandshake.")
            }
        }, onFail: {
            log(.high, info: "Connection closed before receiving ManagedConnectionHandshake")
        })
    }

    // MARK: ConnectionDelegate
    func establishUnderlyingConnection(_ packetConnection: PacketConnection) {
        self.router.establishMulticastConnection(destinations: packetConnection.destinations, onConnection: { connection in
            _ = writeSinglePacket(connection: connection, packet: ManagedConnectionHandshake(connectionIdentifier: packetConnection.connectionIdentifier), onSuccess: {
                packetConnection.swapUnderlyingConnection(connection)
            },
            onFail: {
                log(.medium, error: "Failed to send ManagedConnectionHandshake.")
            })
        }, onFail: {
            log(.medium, error: "Failed to establish connection.")
        })
    }

    func notifyConnectionClose(_ connection: PacketConnection) {
        self.establishedConnections[connection.connectionIdentifier] = nil
        self.incomingConnections[connection.connectionIdentifier] = nil
    }

    func reconnect(_ peer: RemotePeer) {
        for (_, packetConnection) in self.establishedConnections {
            if packetConnection.destinations.contains(peer.node) {
                self.establishUnderlyingConnection(packetConnection)
            }
        }
    }
}
