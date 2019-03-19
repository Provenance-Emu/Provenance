//
//  ForkingConnection.swift
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

// TODO: ignores didSendData - is this ok?
// TODO: might buffer lots of data if incoming connection is fast and outgoing connection is slow.

/**
* A ForkingConnection acts like the incomingConnection it was constructed with, but additionally forwards any data received 
* from the incoming connection to an additional outgoing connection and vice versa. Delegate methods will not be called for any events related to the outgoing connection.
*/
class ForkingConnection: NSObject, UnderlyingConnection, UnderlyingConnectionDelegate {
    /** The ForkingConnection's incoming connection. */
    let incomingConnection: UnderlyingConnection
    /** The ForkingConnection's outgoing connection */
    let outgoingConnection: UnderlyingConnection
    /** A closure to call when the connection closes. */
    let onCloseClosure: (ForkingConnection) -> Void

    /** Constructs a new ForkingConnection. */
    init(incomingConnection: UnderlyingConnection, outgoingConnection: UnderlyingConnection, onClose: @escaping (ForkingConnection) -> Void) {
        self.incomingConnection = incomingConnection
        self.outgoingConnection = outgoingConnection
        self.onCloseClosure = onClose

        super.init()

        self.incomingConnection.delegate = self
        self.outgoingConnection.delegate = self
    }

    func counterpartForConnection(_ connection: UnderlyingConnection) -> UnderlyingConnection {
        if connection === self.incomingConnection {
            return self.outgoingConnection
        }
        if connection === self.outgoingConnection {
            return self.incomingConnection
        }

        log(.high, error: "Trying to get counterpart to unknown connection.")
        let result: UnderlyingConnection? = nil
        return result!
    }

    // MARK: UnderlyingConnection protocol
    var delegate: UnderlyingConnectionDelegate?
    var isConnected: Bool { get { return self.incomingConnection.isConnected && self.outgoingConnection.isConnected } }
    var recommendedPacketSize: Int { get { return self.incomingConnection.recommendedPacketSize } }

    func connect() {
        log(.high, error: "Connect called on Forwarding connection. Should already be connected.")
    }
    func close() {
        self.incomingConnection.close()
        self.outgoingConnection.close()
    }
    func writeData(_ data: Data) {
        self.incomingConnection.writeData(data)
    }

    // MARK: UnderlyingConnectionDelegate protocol

    func didConnect(_ connection: UnderlyingConnection) {
        log(.high, error: "Forwarding connection received a didConnect call. This should not happen as the underlying connections should be established already.")
    }
    func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {
        log(.low, info: "An underlying connection closed. Closing other connection.")
        self.incomingConnection.delegate = nil
        self.outgoingConnection.delegate = nil

        self.counterpartForConnection(connection).close()

        self.delegate?.didClose(self, error: error)
        self.onCloseClosure(self)
    }
    func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
        if connection === incomingConnection {
            self.delegate?.didReceiveData(self, data: data)
        }

        self.counterpartForConnection(connection).writeData(data)
    }
    func didSendData(_ connection: UnderlyingConnection) {
        if connection === self.incomingConnection {
            self.delegate?.didSendData(self)
        }
    }

}
