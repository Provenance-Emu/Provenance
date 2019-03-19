//
//  ReliabilityManager.swift
//  sReto
//
//  Created by Julian Asamer on 13/07/14.
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

var reliabilityManagerDelays = (regularDelay: 1.0, shortDelay: 0.4)

/**
* The ReliablityManager's delegate protocol.
*/
protocol ReliabilityManagerDelegate: class {
    /** Called when the connection connected succesfully. */
    func connectionConnected()
    /** Called when the connection closes expectedly (i.e. when close() was called on the connection) */
    func connectionClosedExpectedly()
    /** Called when the connection failed and could not be reestablished. */
    func connectionClosedUnexpectedly(_ error: AnyObject?)
}

/**
* A ConnectionManager manages PacketConnections.
*/
protocol ConnectionManager: class {
    /**
    * Called when a new underlying connection needs to be established for an packet connection.
    */
    func establishUnderlyingConnection(_ connection: PacketConnection)
    /** 
    * Called when a connection closed.
    */
    func notifyConnectionClose(_ connection: PacketConnection)
}

/**
* The ReliablityManager is responsible for cleanly closing connections and attempting to reconnect failed connections.
*
* TODO: This class currently assumes that if connecting takes longer than a specific amount of time (1 second), the connection attempt failed and tries to reconnect. This causes issues if establishing the connection takes longer than 1 second, especially with routed/multicast connections, causing the connection establishment process to fail. To fix this, the next attempt should only be started after a generous timeout or if the connection establishment process failed, and not if it is still in progress.
*/
class ReliabilityManager: NSObject, PacketHandler {
    /** The PacketConnection thats reliability is managed. */
    fileprivate let packetConnection: PacketConnection
    /** The delegate */
    weak var delegate: ReliabilityManagerDelegate?
    /** The connection manager */
    weak var connectionManager: ConnectionManager?
    /** The dispatch queue used to dispatch delegate methods on */
    let dispatchQueue: DispatchQueue
    /** The local peer's identifier */
    let localIdentifier: UUID
    /** All of the managed connection's destination's identifiers */
    let destinationIdentifiers: Set<UUID>

    /** Set to true when the underlying connection is expected to close. */
    var isExpectingConnectionToClose = false
    /** Set to true if this ReliabilityManager is expected to attempt to reconnect when a connection fails. */
    var isExpectedToReconnect: Bool

    /** The executor used to repeat reconnect attempts */
    var repeatedExecutor: RepeatedExecutor!
    /** The number of reconnect attempts that have been performed */
    var reconnectAttempts: Int = 0
    /** The number of close acknowledge packets received. Necessary since acknowledgements need to be received from all destinations before a connection can be closed safely. */
    var receivedCloseRequestAcknowledges: Set<UUID> = []
    /** If the connection fails, stores the original error so it can be reported in case all reconnect attempts fail. */
    var originalError: AnyObject?

    /** 
    * Constructs a new ReliablityManager.
    * @param packetConnection The packet connection managed
    * @param connectionManager The connection manager responsible for the packet connection.
    * @param isExpectedToReconnect If set to true, this ReliabilityManager will attempt to reconnect the packet connection if its underlying connection fails.
    * @param localIdentifier The local peer's identifier.
    * @param dispatchQueue The dispatch queue on which all delegate method calls are dispatched.
    */
    init(packetConnection: PacketConnection, connectionManager: ConnectionManager, isExpectedToReconnect: Bool, localIdentifier: UUID, dispatchQueue: DispatchQueue) {
        self.packetConnection = packetConnection
        self.connectionManager = connectionManager

        self.isExpectedToReconnect = isExpectedToReconnect
        self.localIdentifier = localIdentifier
        self.dispatchQueue = dispatchQueue
        self.destinationIdentifiers = Set(packetConnection.destinations.map { $0.identifier })

        super.init()

        packetConnection.addDelegate(self)
        self.repeatedExecutor = RepeatedExecutor(regularDelay: reliabilityManagerDelays.regularDelay, shortDelay: reliabilityManagerDelays.shortDelay, dispatchQueue: dispatchQueue)
    }

    /** Closes the packet connection cleanly. */
    func closeConnection() {
        if self.isExpectedToReconnect {
            self.packetConnection.write(CloseAnnounce())
        } else {
            self.packetConnection.write(CloseRequest())
        }
    }

    /** Attempts to reconnect a PacketConnection with no or a failed underlying connection. */
    func attemptReconnect() {
        if self.packetConnection.isConnected {
            return
        }

        self.reconnectAttempts += 1

        if self.reconnectAttempts > 5 {
            self.repeatedExecutor.stop()
            self.connectionManager?.notifyConnectionClose(self.packetConnection)
            self.delegate?.connectionClosedUnexpectedly(self.originalError)
        } else {
            self.repeatedExecutor.start(self.attemptReconnect)
            self.connectionManager?.establishUnderlyingConnection(self.packetConnection)
        }
    }

    /** Handles a close request. */
    fileprivate func handleCloseRequest() {
        self.packetConnection.write(CloseAnnounce())
    }

    /** Handles a close announce. */
    fileprivate func handleCloseAnnounce() {
        self.isExpectingConnectionToClose = true
        self.packetConnection.write(CloseAcknowledge(source: self.localIdentifier))
    }

    /** Handles a close acknowledge. */
    fileprivate func handleCloseAcknowledge(_ packet: CloseAcknowledge) {
        self.receivedCloseRequestAcknowledges += packet.source
        if self.receivedCloseRequestAcknowledges == self.destinationIdentifiers {
            self.isExpectingConnectionToClose = true
            self.receivedCloseRequestAcknowledges = []
            self.packetConnection.disconnectUnderlyingConnection()
        }
    }

    // MARK: PacketConnection delegate

    func underlyingConnectionDidClose(_ error: AnyObject?) {
        self.originalError = error

        if self.isExpectingConnectionToClose {
            self.repeatedExecutor.stop()
            self.connectionManager?.notifyConnectionClose(self.packetConnection)
            self.delegate?.connectionClosedExpectedly()
        } else {
            self.repeatedExecutor.start(self.attemptReconnect)
        }
    }

    func willSwapUnderlyingConnection() {
    }

    func underlyingConnectionDidConnect() {
        self.originalError = nil
        self.reconnectAttempts = 0
        self.repeatedExecutor.stop()

        self.delegate?.connectionConnected()
    }

    func didWriteAllPackets() {
    }

    let handledPacketTypes = [PacketType.closeRequest, PacketType.closeAnnounce, PacketType.closeAcknowledge]

    func handlePacket(_ data: DataReader, type: PacketType) {
        switch type {
        case .closeRequest:
            handleCloseRequest()
            break
        case .closeAnnounce:
            handleCloseAnnounce()
            break
        case .closeAcknowledge:
            if let packet = CloseAcknowledge.deserialize(data) {handleCloseAcknowledge(packet)}
            break
        default:
            log(.medium, error: "Unknown packet type.")
        }
    }
}
