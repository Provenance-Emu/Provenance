//
//  DummyConnection.swift
//  sReto
//
//  Created by Julian Asamer on 17/09/14.
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

class DummyConnection: NSObject, UnderlyingConnection {
    var delegate: UnderlyingConnectionDelegate?
    var isConnected: Bool = false
    var recommendedPacketSize: Int { get { return self.networkInterface.recommendedPacketSize } }
    var counterpartConnection: DummyConnection?
    let networkInterface: DummyNetworkInterface

    init(networkInterface: DummyNetworkInterface) {
        self.networkInterface = networkInterface
    }

    func connect() {}
    func close() {
        if !self.isConnected {
            print("called close on disconnected connection.")
            return
        }

        DispatchQueue.main.async {
            self.internalClose()
            self.counterpartConnection?.internalClose()
        }
    }
    func internalClose() {
        if !self.isConnected {
            print("called close on disconnected connection.")
            return
        }

        self.isConnected = false
        self.delegate?.didClose(self, error: "Internal test close" as AnyObject?)
    }

    func writeData(_ data: Data) {
        let type = DataReader(data).getInteger()
        if let type = PacketType(rawValue: type) {
            if type == PacketType.unknown {
                print("Trying to send packet with invalid type.")
            }
        }

        DispatchQueue.main.async {
            self.counterpartConnection?.internalReceiveData(data: data)
            self.delegate?.didSendData(self)
        }
    }
    func internalReceiveData(data: Data) {
        self.delegate?.didReceiveData(self, data: data)
    }
}

class DummyOutConnection: DummyConnection {
    var inConnection: DummyInConnection

    init(networkInterface: DummyNetworkInterface, advertiser: DummyAdvertiser) {
        self.inConnection = DummyInConnection(networkInterface: networkInterface, advertiser: advertiser)

        super.init(networkInterface: networkInterface)

        self.counterpartConnection = self.inConnection
        self.inConnection.outConnection = self
        self.inConnection.counterpartConnection = self
    }
    override func connect() {
        self.isConnected = true
        self.inConnection.internalAnnounceOpen()

        self.delegate?.didConnect(self)
    }
}

class DummyInConnection: DummyConnection {
    var outConnection: DummyOutConnection!

    let advertiser: DummyAdvertiser

    init(networkInterface: DummyNetworkInterface, advertiser: DummyAdvertiser) {
        self.advertiser = advertiser

        super.init(networkInterface: networkInterface)

        self.isConnected = true
    }
    func internalAnnounceOpen() {
        self.advertiser.onConnection(connection: self)
    }
    override func connect() {
        print("Connect called in incoming connection. Ignored.")
    }
}
