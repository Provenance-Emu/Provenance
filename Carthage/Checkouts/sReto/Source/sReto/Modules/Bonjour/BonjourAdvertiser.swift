//
//  BonjourAdvertiser.swift
//  sReto
//
//  Created by Julian Asamer on 25/07/14.
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

protocol BonjourServiceAdvertiserDelegate : class {
    func didPublish()
    func didNotPublish()
    func didStop()
}

protocol BonjourServiceAdvertiser : class {
    weak var delegate: BonjourServiceAdvertiserDelegate? { get set }

    func startAdvertising(_ name: String, type: String, port: UInt)
    func stopAdvertising()
}

class BonjourAdvertiser: NSObject, Advertiser, GCDAsyncSocketDelegate, BonjourServiceAdvertiserDelegate {
    var advertiserDelegate: AdvertiserDelegate?
    var isAdvertising: Bool = false

    fileprivate let networkType: String
    fileprivate let dispatchQueue: DispatchQueue
    fileprivate var advertiser: BonjourServiceAdvertiser
    fileprivate let recommendedPacketSize: Int
    //this array stores connections that would be deinitialized otherwised
    fileprivate var connections = [UnderlyingConnection]()

    var acceptingSocket: GCDAsyncSocket?

    init(networkType: String, dispatchQueue: DispatchQueue, advertiser: BonjourServiceAdvertiser, recommendedPacketSize: Int) {
        self.networkType = networkType
        self.dispatchQueue = dispatchQueue
        self.advertiser = advertiser
        self.recommendedPacketSize = recommendedPacketSize

        super.init()
    }

    func startAdvertising(_ identifier : UUID) {
        let acceptingSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatchQueue, socketQueue: dispatchQueue)
        self.acceptingSocket = acceptingSocket

        var error : NSError?
        do {
            try acceptingSocket.accept(onPort: 0)
        } catch let error1 as NSError {
            error = error1
            log(.high, error: "An error occured when trying to listen for incoming connections: \(String(describing: error))")
            return
        }

        self.advertiser.delegate = self
        self.advertiser.startAdvertising(identifier.UUIDString, type: self.networkType, port: UInt(acceptingSocket.localPort))
        self.isAdvertising = true
    }

    func stopAdvertising() {
        self.acceptingSocket?.disconnect()
        self.advertiser.stopAdvertising()
        self.isAdvertising = false
        self.connections.removeAll()
    }

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let connection = AsyncSocketUnderlyingConnection(socket: newSocket, recommendedPacketSize: 32*1024)
        connections.append(connection)
        if let delegate = self.advertiserDelegate {
            delegate.handleConnection(self, connection: connection)
        } else {
            log(.high, error: "Received incoming connection, but there's no delegate set.")
        }
    }

    func didPublish() {
        self.advertiserDelegate?.didStartAdvertising(self)
    }

    func didNotPublish() {
        log(.medium, error: "failed to publish advertisement.")
        self.isAdvertising = false
        self.advertiser.stopAdvertising()
    }

    func didStop() {
        self.advertiserDelegate?.didStopAdvertising(self)
        self.isAdvertising = false
    }
}
