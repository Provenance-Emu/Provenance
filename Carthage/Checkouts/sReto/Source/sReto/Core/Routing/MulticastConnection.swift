//
//  MulticastConnection.swift
//  sReto
//
//  Created by Julian Asamer on 18/09/14.
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
* A MulticastConnection acts like a normal underlying connection, but sends all data written to it using a set of subconnections.
* Data received from any subconnection is reported to the delegate.
*/
class MulticastConnection: UnderlyingConnection, UnderlyingConnectionDelegate {
    /** The subconnections used with this connection */
    var subconnections: [UnderlyingConnection] = []

    /** Stores the number of dataSent calls yet to be received. Once all are received, the delegate's didSendData can be called. */
    var dataSentCallbacksToBeReceived: Int = 0
    /** The number of data packets that have been sent in total. */
    var dataPacketsSent: Int = 0

    init() {}
    /** Adds a subconnection. */
    func addSubconnection(_ connection: UnderlyingConnection) {
        self.subconnections.append(connection)
        connection.delegate = self
    }

    // MARK: UnderlyingConnection protocol
    var delegate: UnderlyingConnectionDelegate?
    var isConnected: Bool { get { return subconnections.map({ $0.isConnected }).reduce(false, { $0 && $1 }) } }
    var recommendedPacketSize: Int { get { return subconnections.map { $0.recommendedPacketSize }.min()! } }

    func connect() {
        for connection in self.subconnections {
            connection.connect()
        }
    }

    func close() {
        for connection in self.subconnections {
            connection.close()
        }
    }

    func writeData(_ data: Data) {
        if self.dataSentCallbacksToBeReceived != 0 {
            self.dataPacketsSent += 1
        } else {
            self.dataSentCallbacksToBeReceived = self.subconnections.count
        }

        for connection in self.subconnections {
            connection.writeData(data)
        }
    }

    // MARK: UnderlyingConnectionDelegate protocol
    func didConnect(_ connection: UnderlyingConnection) {
        if self.isConnected { self.delegate?.didConnect(self) }
    }

    func didClose(_ closedConnection: UnderlyingConnection, error: AnyObject?) {
        for connection in self.subconnections {
            if connection !== closedConnection { connection.close() }
        }

        self.delegate?.didClose(self, error: error )
    }

    func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
        self.delegate?.didReceiveData(self, data: data)
    }

    func didSendData(_ connection: UnderlyingConnection) {
        if self.dataSentCallbacksToBeReceived == 0 {
            log(.medium, info: "Received unexpected didSendData call.")
            return
        }

        self.dataSentCallbacksToBeReceived -= 1

        if self.dataSentCallbacksToBeReceived == 0 {
            if self.dataPacketsSent != 0 {
                self.dataPacketsSent -= 1
                self.dataSentCallbacksToBeReceived = self.subconnections.count
            }

            self.delegate?.didSendData(self)
        }
    }
}
