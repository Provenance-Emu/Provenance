//
//  TransferConnection.swift
//  sReto
//
//  Created by Julian Asamer on 15/07/14.
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
* Connection objects can be used to send and receive data. They can be established by calling connect on a RemotePeer or the LocalPeer.
* If necessary, routing will be used automatically if a remote peer is not reachable directly. The Connection object will also automatically attempt to reconnect to a peer, should a route become unavailable. 
* Furthermore, the Connection object will attempt to automatically upgrade the connection to the remote peer if a better route becomes available.
*
* Events
* The Connection class gives access to five events, onConnect, onTransfer, onData, onClose, and onError. You can react to the events by simply setting a closure, e.g.
* connection.onData = { data in print("received \(data.length) bytes") }
* None of these events have to be handled, however, if you wish to receive data, you need to react to either the onTransfer or onData event.
*
* Sending Data
* Data can be sent using the methods send(data: NSData) -> Transfer and send(dataLength: Int, dataProvider: (range: Range) -> NSData) -> Transfer. 
* The latter method allows you to generate data as it is sent, e.g. to load it from a file on demand.
*
* Receiving Data
* The Connection class offers two means of receiving data that are mutually exclusive:
* 1. Setting onData: the closure will be called whenever data is received. For each send method call on the remote peer, 
*    onData will be called once when the data is transmitted. This is a convenience method and does not give you access to any additional information about transfers.
* 2. Setting onTransfer: This closure is called when a data transfer starts, i.e. before the data is transmitted.
*    It gives access to a InTransfer object that allows you to respond to events (such as progress updates), and allows you to specify how the transfer should be received. It can also be used to cancel transfers.
*/

@objc open class Connection: NSObject, TransferManagerDelegate, ReliabilityManagerDelegate {
    /** Whether this connection is currently connected. */
    open var isConnected: Bool = false

    // MARK: Events

    /** 
    * Called when the connection connects successfully. If the connection is already connected when this property is set, it is called immediately.
    * Passes the connection that connected as a parameter.
    */
    open var onConnect: ((_ connection: Connection) -> Void)? = nil {
        didSet {
            if isConnected {
                onConnect?(self)
            }
        }
    }
    /** 
    * Called when an incoming transfer starts. It's possible to specify how the data is received, cancel the transfer, receive progress updates. 
    * Passes the connection that received the transfer and the transfer object as parameters.
    */
    open var onTransfer: ((_ connection: Connection, _ transfer: InTransfer) -> Void)?
    /** 
    * Convenience alternative to onTransfer. If set, transfers are received automatically, and passed to this closure on completion. Is used only if onTransfer is not set. 
    */
    open var onData: ((_ data: Data) -> Void)?
    /** 
    * Called when the connection closes. Passes the connection that closed as the parameter.
    */
    open var onClose: ((_ connection: Connection) -> Void)?
    /** 
    * Called when an error occurs that caused the connection to close. If not set, onClose will be called when an error occurs. Passes the connection that closed as the parameter.
    */
    open var onError: ((_ connection: Connection, _ error: AnyObject) -> Void)?

    // MARK: Sending Data

    /**
    * Sends data.
    * @param data The data that should be sent.
    * @return A Transfer object. Can be used to query about information of the transfer, cancel the transfer, and offers events related to the transfer. Can be ignored.
    */
    open func send(data: Data) -> Transfer {
        return self.send(dataLength: data.count, dataProvider: { data.subdata(in: $0) })
    }

    /**
    * Sends data.
    * @param data The data that should be sent.
    * @return A Transfer object. Can be used to query about information of the transfer, cancel the transfer, and offers events related to the transfer. Can be ignored.
    */
    open func send(_ data: Data) {
        _ = self.send(dataLength: data.count, dataProvider: { data.subdata(in: $0) })
    }

    /**
    * Sends data. Uses a data provider closure that allows to specify data as it is sent.
    * @param dataLength The number of bytes to be sent.
    * @param dataProvider A closure that returns a subrange of the data that should be sent.
    * @return A Transfer object. Can be used to query about information of the transfer, cancel the transfer, and offers events related to the transfer.
    */
    open func send(dataLength: Int, dataProvider: @escaping (_ range: Range<Data.Index>) -> Data) -> Transfer {
        let transfer = self.transferManager.startTransfer(dataLength, dataProvider: dataProvider)
        return transfer
    }

    // MARK: Miscellaneous

    /**
    * Closes the connection.
    */
    open func close() {
        self.reliabilityManager.closeConnection()
    }

    /**
    * If the connection closed for any reason, this method will attempt to reestablish it.
    */
    open func reconnect() {
        if self.isConnected {
            log(.low, error: "Cannot attempt reconnect while connected.")
            return
        }

        self.reliabilityManager.attemptReconnect()
    }

    // MARK: Internal
    let dispatchQueue: DispatchQueue

    /** The trasfer manager, which is responsible for data transmissions. */
    let transferManager: TransferManager
    /** The reliability manager, which is responsible for cleanly closing connections and providing automatic reconnect functionality. */
    let reliabilityManager: ReliabilityManager
    /** 
    * A list of transfers that were automatically received. This is used when the onData event is used, as opposed to the onTransfer even, in which case
    * the user is responsible to receive transfers.
    */
    var autoreceivedTransfers: [UUID: InTransfer] = [:]
    /**
    * A connection will self-retain itself as long as it is connected using this self-reference.
    */
    var retainCycle: Connection?

    /**
    * Constructs a Connection. Users should use RemotePeer and LocalPeer's connect() methods to establish connections.
    *
    * @param packetConnection The packet connection used by this connection.
    * @param localIdentifier: The local peer's identifier
    * @param dispatchQueue The dispatch queue delegate methods and events are dispatched on
    * @param isConnectionEstablisher: A boolean indicating whether the connection was established on this peer. If the connection closes unexpectedly, the
    *           connection establisher is responsible for any reconnect attempts.
    * @param connectionManager The connection's manager. If a reconnect is required, it is responsible to establish a new underlying connection.
    */
    init(packetConnection: PacketConnection, localIdentifier: UUID, dispatchQueue: DispatchQueue, isConnectionEstablisher: Bool, connectionManager: ConnectionManager) {
        self.dispatchQueue = dispatchQueue

        self.transferManager = TransferManager(packetConnection: packetConnection)
        self.reliabilityManager = ReliabilityManager(packetConnection: packetConnection, connectionManager: connectionManager, isExpectedToReconnect: isConnectionEstablisher, localIdentifier: localIdentifier, dispatchQueue: dispatchQueue)

        super.init()

        self.transferManager.delegate = self
        self.reliabilityManager.delegate = self

        if packetConnection.isConnected {
            self.connectionConnected()
        }

        self.retainCycle = self
    }

    /** Receives a transfer. When done, the onData event is invoked. */
    fileprivate func autoreceive(_ transfer: InTransfer) {
        self.autoreceivedTransfers[transfer.identifier] = transfer

        transfer.onCompleteData = {
            transfer, data in
            self.onData?(data as Data)
            return
        }
        transfer.onComplete = {
            _ in
            self.autoreceivedTransfers[transfer.identifier] = nil
        }
    }

    // MARK: ReliabilityManager delegate
    func connectionConnected() {
        if !self.isConnected {
            self.isConnected = true
            self.onConnect?(self)
        }
    }

    func connectionClosedExpectedly() {
        self.isConnected = false
        self.retainCycle = nil
        self.onClose?(self)
    }

    func connectionClosedUnexpectedly(_ error: AnyObject?) {
        self.isConnected = false
        self.retainCycle = nil
        if !(self.onError?(self, error ?? "Unexpected connection close." as AnyObject) != nil) {
            self.onClose?(self)
        }
    }

    // MARK: TransferManager delegate
    func notifyTransferStarted(_ transfer: InTransfer) {
        if (self.onTransfer != nil) {
            self.onTransfer!(self, transfer)
        } else if (self.onData != nil) {
            self.autoreceive(transfer)
        } else {
            log(.high, error: "You need to set either onTransfer or onData on connection \(self).")
        }
    }
}
