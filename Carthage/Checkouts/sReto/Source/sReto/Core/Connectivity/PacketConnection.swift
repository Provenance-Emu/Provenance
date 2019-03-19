//
//  PacketConnection.swift
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

/**
* PacketConnections are used to send and receive packets. Packets used by Reto can be any data of any fixed length, 
* but the first four bytes always contain the packet's type.
*
* A PacketConnection encapsulates the idea of a logical connection. It adds an additional indirection between a Connection as provided by 
* the Reto API and underlying connections. This allows the PacketConnection to switch between different underlying connections, and even exist without
* an underlying connection. This is the basis of features such as automatic reconnect, and offering automatic connection upgrades.
*
* Packets can be sent by calling the write() method. If data is currently written, or no underlying connection is available, the packet is buffered
* until it can be sent. 
*
* A PacketConnection can have multiple delegates. Amongt other events, the PacketConnection delegates the handling of packets to multiple delegates that implement
* the PacketHandler protocol. The PacketHandlers may specify the packet types they are able to handler, the packet connection will call the according handler's
* handlePacket method.
*
* The PacketConnection itself is agnostic of the different packet types, the introduction of new packet types and handlers does not require any changes
* in the PacketConnection class. This allows Reto to split up different functionality of Connections into different classes, 
* e.g. the TransferManager and ReliabilityManager, which are both PacketHandlers.
*/

/**
* The delegate protocol used with the PacketConnection.
*/
protocol PacketConnectionDelegate: class {
    /** Called when the underlying connection closed. */
    func underlyingConnectionDidClose(_ error: AnyObject?)
    /** Called when the underlying connection is about to be switched to a different one. */
    func willSwapUnderlyingConnection()
    /** Called when confirmation that the underlying connection did connect is received. */
    func underlyingConnectionDidConnect()
    /** Called whenever all packets that were queued have been sent, i.e. the connection is ready for more data if available. */
    func didWriteAllPackets()
}

/**
* The PacketHandler protocol extends the PacketConnectionDelegate protocol and is used by delegates that are able to handle packets of certain types.
* Hence, it allows it's implementors to specify for which packet type the handlePacket method should be called.
* Note that each packet type may only be handled by a single handler.
*/
protocol PacketHandler: PacketConnectionDelegate {
    /** An array of packet types that are handled by this PacketHandler. */
    var handledPacketTypes: [PacketType] { get }
    /** Called when a packet is received that should be handled */
    func handlePacket(_ data: DataReader, type: PacketType)
}

/**
* Used to store weak references in an array by introducing an additional indirection since Swift arrays cannot store weak references directly.
*/
class WeakPacketConnectionDelegate {
    weak var delegate: PacketConnectionDelegate?

    init(delegate: PacketConnectionDelegate) {
        self.delegate = delegate
    }
}

class WeakPacketHandler {
    weak var handler: PacketHandler?

    init(handler: PacketHandler) {
        self.handler = handler
    }
}

class PacketConnection: UnderlyingConnectionDelegate {
    /**
    * The PacketConnection's delegates.
    */
    var delegates: [WeakPacketConnectionDelegate] = []
    /** The PacketConnection's delegates. */
    var packetHandlers: [PacketType: WeakPacketHandler] = [:]
    /** The underlying connection used by this PacketConnection */
    fileprivate(set) var underlyingConnection: UnderlyingConnection?
    /** The connection's identifier. This identifier is used to associate new incoming underlying connections with exising packet connections. */
    let connectionIdentifier: UUID
    /** This connection's destinations. */
    let destinations: Set<Node>
    /** Buffer for unsent packets. */
    var unsentPackets: [Packet] = []
    /** Whether a packet is currently being sent. */
    var isSendingPacket: Bool = false
    /** Whether the connection is connected or not. */
    var isConnected: Bool {
        return self.underlyingConnection?.isConnected ?? false
    }

    /** 
    * Initializes a new PacketConnection.
    * 
    * @param connection An underlying connection to use with this packet connection. May be nil and set later.
    * @param connectionIdentifier This connection's identifier.
    * @param destinations The connection's destinations.
    */
    init(connection: UnderlyingConnection?, connectionIdentifier: UUID, destinations: Set<Node>) {
        self.underlyingConnection = connection
        self.connectionIdentifier = connectionIdentifier
        self.destinations = destinations

        if let connection = connection { connection.delegate = self }
        if self.isConnected { self.didConnect() }
    }

    /** Add a PacketConnectionDelegate */
    func addDelegate(_ delegate: PacketConnectionDelegate) {
        self.delegates.append(WeakPacketConnectionDelegate(delegate: delegate))
    }

    /** Add a PacketHandler */
    func addDelegate(_ delegate: PacketHandler) {
        self.delegates.append(WeakPacketConnectionDelegate(delegate: delegate))

        for type in delegate.handledPacketTypes {
            if let handler = self.packetHandlers[type] {
                log(.high, warning: "For packet type \(type), there already is the packet handler \(handler). It will be overwritten with \(delegate).")
            }

            self.packetHandlers[type] = WeakPacketHandler(handler: delegate)
        }
    }

    /** Used internally to simplify notifying all delegates. */
    fileprivate func notifyDelegates(_ closure: (PacketConnectionDelegate) -> Void) {
        for weakDelegate in self.delegates {
            if let delegate = weakDelegate.delegate {
                closure(delegate)
            }
        }
    }

    /**
    * Swaps this PacketConnection's underlying connection to a new one. The new connection can also be nil, in that case the packet connection will be disconnected.
    */
    func swapUnderlyingConnection(_ underlyingConnection: UnderlyingConnection?) {
        if (self.underlyingConnection === underlyingConnection) {
            return
        }

        if self.underlyingConnection != nil {
            self.notifyDelegates { $0.willSwapUnderlyingConnection() }
        }
        let previousConnection = self.underlyingConnection
        self.underlyingConnection = underlyingConnection
        if let underlyingConnection = self.underlyingConnection {
            underlyingConnection.delegate = self
        }

        if let previousConnection = previousConnection {
            if previousConnection.isConnected {
                previousConnection.close()
            }
        }
        self.isSendingPacket = false
        self.unsentPackets = []

        if let underlyingConnection = self.underlyingConnection {
            if underlyingConnection.isConnected {
                self.didConnect()
            }
        }
    }

    /**
    * Closes the underlying connection
    */
    func disconnectUnderlyingConnection() {
        self.underlyingConnection?.close()
    }

    /**
    * Writes a packet. The packet will be buffered and sent later if the connection is currently disconnected.
    */
    func write(_ packet: Packet) {
        self.unsentPackets.append(packet)
        self.write()
    }

    /**
    * Attempts to write any buffered packets, or notifies it's delegates that all packes have been written.
    */
    func write() {
        if self.isSendingPacket {
            return
        }
        if let underlyingConnection = self.underlyingConnection {
            if !underlyingConnection.isConnected {
                return
            }

            if (self.unsentPackets.count == 0) {
                self.notifyDelegates { $0.didWriteAllPackets() }
            } else {
                self.isSendingPacket = true
                underlyingConnection.writeData(self.unsentPackets.remove(at: 0).serialize())
            }
        }
    }

    func didConnect() {
        self.notifyDelegates { $0.underlyingConnectionDidConnect() }
    }

    // MARK: UnderlyingConnectionDelegate methods.
    func didConnect(_ connection: UnderlyingConnection) {
        if connection !== self.underlyingConnection { return }

        self.didConnect()
    }
    func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {
        if connection !== self.underlyingConnection { return }

        self.notifyDelegates { $0.underlyingConnectionDidClose(error) }
    }
    func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
        if connection !== self.underlyingConnection { return }

        let dataReader = DataReader(data)
        let packetType = dataReader.getInteger()
        dataReader.rewind()

        if let packetType = PacketType(rawValue: packetType) {
            if let handler = self.packetHandlers[packetType]?.handler {
                handler.handlePacket(dataReader, type: packetType)
            } else {
                log(.high, warning: "There was no PacketHandler registered for the type \(packetType) (raw: \(packetType.rawValue)) with the PacketConnection \(self). It will be dismissed.")
            }
        } else {
            log(.high, error: "Unknown packet type: \(packetType)")
        }
    }
    func didSendData(_ connection: UnderlyingConnection) {
        self.isSendingPacket = false
        self.write()
    }
}
