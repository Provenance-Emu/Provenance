//
//  AsyncSocketUnderlyingConnection.swift
//  sReto
//
//  Created by Julian Asamer on 09/07/14.
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
import CocoaAsyncSocket

enum AddressInformation {
    case addressAsData(Data, String, Int)
    case hostName(String, Int)
}

class AsyncSocketUnderlyingConnection: NSObject, UnderlyingConnection {
    let HEADER_TAG = 1
    let BODY_TAG = 2

    let socket: GCDAsyncSocket
    let recommendedPacketSize: Int
    var isConnected: Bool {
        return self.socket.isConnected
    }

    //TODO: this delegate is not weak because otherwise no one holds it and it gets deinitialized
    /*weak */var delegate: UnderlyingConnectionDelegate?

    let addressInformation: AddressInformation?

    init(socket: GCDAsyncSocket, recommendedPacketSize: Int) {
        self.socket = socket
        self.recommendedPacketSize = recommendedPacketSize
        self.addressInformation = nil

        super.init()

        self.socket.delegate = self

        if self.isConnected {
            self.readHeader()
        }
    }

    init(dispatchQueue: DispatchQueue, recommendedPacketSize: Int, addressInformation: AddressInformation) {
        self.socket = GCDAsyncSocket(delegate: nil, delegateQueue: dispatchQueue, socketQueue: dispatchQueue)
        self.recommendedPacketSize = recommendedPacketSize
        self.addressInformation = addressInformation

        super.init()

        self.socket.delegate = self

        if self.isConnected {
            self.readHeader()
        }
    }

    func connect() {
        if (self.isConnected) {
            return
        }

        if let addressInformation = self.addressInformation {
            var error : NSError?

            switch addressInformation {
                case .addressAsData(let data, let hostName, let port):
                    log(.medium, info: "try to connect to address data: \(data), hostName: \(hostName), port: \(port)")
                    do {
                        try socket.connect(toAddress: data)
                    } catch let error1 as NSError {
                        error = error1
                    }
                    break
                case .hostName(let hostName, let port):
                    log(.medium, info: "try to connect to: \(hostName), port: \(port)")
                    do {
                        try socket.connect(toHost: hostName, onPort: UInt16(port))
                    } catch let error1 as NSError {
                        error = error1
                    }
                    break
            }

            if let error = error {
                log(.medium, error: "Error occured when trying to connect: \(error)")
                self.delegate?.didClose(self, error: error)
            }

        } else {
            log(.medium, error: "Could not connect. This connection has no address information.")
        }
    }

    func close() {
        self.socket.disconnectAfterReadingAndWriting()
    }

}

extension AsyncSocketUnderlyingConnection: GCDAsyncSocketDelegate {

    func socket(_ socket: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        log(.low, info: "socket connected to: \(host), port: \(port)")
        self.delegate?.didConnect(self)
        self.readHeader()
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        log(.medium, info: "socket disconnect, error: \(String(describing: err))")
        self.delegate?.didClose(self, error: err as AnyObject?)
    }

    func readHeader() {
        self.socket.readData(toLength: UInt(MemoryLayout<Int32>.size), withTimeout: -1, tag: HEADER_TAG)
    }

    func writeData(_ data: Data) {
        if (self.socket.isConnected) {
            let writer = DataWriter(length: MemoryLayout<Int32>.size)
            writer.add(Int32(data.count))

            self.socket.write(writer.getData() as Data, withTimeout: -1, tag: HEADER_TAG)
            self.socket.write(data, withTimeout: -1, tag: BODY_TAG)
        } else {
            log(.low, error: "attempted to write before connected.")
        }
    }

    func socket(_ socket: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == BODY_TAG {
            self.delegate?.didSendData(self)
        }
    }

    func socket(_ socket: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == HEADER_TAG {
            let length = DataReader(data).getInteger()
            socket.readData(toLength: UInt(length), withTimeout: -1, tag: BODY_TAG)
        } else {
            self.delegate?.didReceiveData(self, data: data)
            self.readHeader()
        }
    }
}
