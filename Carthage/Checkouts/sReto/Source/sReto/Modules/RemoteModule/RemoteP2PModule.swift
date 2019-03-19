//
//  RemoteModule.swift
//  sReto
//
//  Created by Julian Asamer on 06/08/14.
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
import SocketRocket

/**
* Using a RemoteP2PModule with the LocalPeer allows it to discover and connect with other peers over the internet using a RemoteP2P server.
*
* To use this module, you need to first deploy the RemoteP2P server (it can be found in the RemoteP2P directory in Reto's repository).
*
* Besides that, if you wish to use the RemoteP2P module, all you need to do is construct an instance and pass it to the LocalPeer either in the constructor or using the addModule method.
* */
open class RemoteP2PModule: Module, Advertiser, Browser {

    open var browserDelegate: BrowserDelegate?
    open var advertiserDelegate: AdvertiserDelegate?
    open var isBrowsing: Bool { get { return self.wantsToBrowse && self.isConnected } }
    open var isAdvertising: Bool { get { return self.wantsToAdvertise && self.isConnected } }
    open var isConnected: Bool = false

    var wantsToAdvertise: Bool = false
    var wantsToBrowse: Bool = false
    var localPeerIdentifier: UUID = UUID_ZERO
    let discoveryUrl: URL
    let requestConnectionUrl: URL
    let acceptConnectionUrl: URL
    var discoverySocket: SRWebSocket?
    var addresses: [UUID: RemoteP2PAddress] = [:]
    // Temporary storage to keep the handlers from being deallocated
    var acceptSocketHandlers: Set<AcceptingConnectionSocketDelegate> = []

    override open var description: String {
        return "RemoteP2PModule: {" +
            "isAdvertising: \(self.isAdvertising), " +
            "isBrowsing: \(self.isBrowsing), " +
            "discoverySocket: \(String(describing: self.discoverySocket)), " +
            "addresses: \(self.addresses)}"
    }

    public init(baseUrl: URL, dispatchQueue: DispatchQueue) {
        self.discoveryUrl = baseUrl.appendingPathComponent("RemoteP2P/discovery")
        self.requestConnectionUrl = baseUrl.appendingPathComponent("RemoteP2P/connection/request/")
        self.acceptConnectionUrl = baseUrl.appendingPathComponent("RemoteP2P/connection/accept/")
        super.init(dispatchQueue: dispatchQueue)
        super.advertiser = self
        super.browser = self
    }

    deinit {
        if let socket = self.discoverySocket {
            socket.close()
        }
    }

    func startDiscoverySocket() {
        if self.discoverySocket != nil { return }

        let socket = SRWebSocket(urlRequest: URLRequest(url: self.discoveryUrl))
        socket?.setDelegateDispatchQueue(self.dispatchQueue)
        socket?.delegate = self
        socket?.open()
        self.discoverySocket = socket
    }

    func stopDiscoverySocket() {
        if !isBrowsing && !isAdvertising {
            self.isConnected = false
            self.discoverySocket?.close()
            self.discoverySocket = nil
        }
    }

    open func startBrowsing() {
        startDiscoverySocket()
        self.wantsToBrowse = true
        self.sendRemotePacket(.startBrowsing)
    }

    open func stopBrowsing() {
        stopDiscoverySocket()
        self.wantsToBrowse = false
        self.sendRemotePacket(.stopBrowsing)
    }

    open func startAdvertising(_ identifier: UUID) {
        self.localPeerIdentifier = identifier
        self.wantsToAdvertise = true
        startDiscoverySocket()
        self.sendRemotePacket(.startAdvertisement)
    }

    open func stopAdvertising() {
        self.wantsToAdvertise = false
        stopDiscoverySocket()
        self.sendRemotePacket(.stopAdvertisement)
    }

    func sendRemotePacket(_ type: RemoteP2PPacketType) {
        if let socket = self.discoverySocket {
            if !self.isConnected { return }
            let packet = RemoteP2PPacket(type: type, identifier: self.localPeerIdentifier)
            socket.send(packet.serialize())
        }
    }

    func addPeer(_ identifier: UUID) {
        log(.low, info: "discovered peer: \(identifier.UUIDString)")

        if (self.isBrowsing) {
            let connectionRequestUrl = self.requestConnectionUrl
                .appendingPathComponent(self.localPeerIdentifier.UUIDString)
                .appendingPathComponent(identifier.UUIDString)
            let address = RemoteP2PAddress(serverUrl: connectionRequestUrl, dispatchQueue: self.dispatchQueue)
            self.addresses[identifier] = address
            self.browserDelegate?.didDiscoverAddress(self, address: address, identifier: identifier)
        }
    }

    func removePeer(_ identifier: UUID) {
        if (self.isBrowsing) {
            let address = self.addresses[identifier]
            self.addresses[identifier] = nil
            if let address = address {
                self.browserDelegate?.didRemoveAddress(self, address: address, identifier: identifier)
            } else {
                log(.low, warning: "attempted to remove an address for which no address exists.")
            }
        }
    }

    class AcceptingConnectionSocketDelegate: NSObject, SRWebSocketDelegate {
        let openBlock: (AcceptingConnectionSocketDelegate) -> Void
        let failBlock: (AcceptingConnectionSocketDelegate) -> Void

        init(openBlock: @escaping (AcceptingConnectionSocketDelegate) -> Void, failBlock: @escaping (AcceptingConnectionSocketDelegate) -> Void) {
            self.openBlock = openBlock
            self.failBlock = failBlock
        }

        func webSocketDidOpen(_ webSocket: SRWebSocket!) {
            openBlock(self)
        }
        func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {}
        func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) { failBlock(self) }
        func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) { failBlock(self) }
    }

    func respondToConnectionRequest(_ identifier: UUID) {
        let acceptConnectionUrl = self.acceptConnectionUrl
            .appendingPathComponent(self.localPeerIdentifier.UUIDString)
            .appendingPathComponent(identifier.UUIDString)
        let socket = SRWebSocket(url: acceptConnectionUrl)
        socket?.setDelegateDispatchQueue(self.dispatchQueue)
        let socketHandler = AcceptingConnectionSocketDelegate(
            openBlock: {
                socketHandler in
                self.advertiserDelegate?.handleConnection(self, connection: RemoteP2PConnection(socket: socket!, dispatchQueue: self.dispatchQueue))
                self.acceptSocketHandlers -= socketHandler
                return ()
            },
            failBlock: {
                socketHandler in
                self.acceptSocketHandlers -= socketHandler
                return ()
            }
        )
        acceptSocketHandlers += socketHandler
        socket?.delegate = socketHandler
        socket?.open()
    }
}

extension RemoteP2PModule: SRWebSocketDelegate {

    public func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        self.isConnected = true
        if self.wantsToAdvertise {
            self.sendRemotePacket(.startAdvertisement)
            self.advertiserDelegate?.didStartAdvertising(self)
        }
        if self.isBrowsing {
            self.sendRemotePacket(.startBrowsing)
            self.browserDelegate?.didStartBrowsing(self)
        }
    }

    public func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        log(.medium, info: "Closed discovery websocket with close code: \(code), reason: \(reason), wasCLean: \(wasClean)")
        self.isConnected = false
        self.discoverySocket = nil
        self.browserDelegate?.didStopBrowsing(self)
        self.advertiserDelegate?.didStopAdvertising(self)
    }

    public func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        log(.medium, info: "Discovery WebSocket failed with error: \(error)")
        self.isConnected = false
        self.discoverySocket = nil
        self.browserDelegate?.didStopBrowsing(self)
        self.advertiserDelegate?.didStopAdvertising(self)
    }

    public func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let data = message as? Data {
            if let packet = RemoteP2PPacket.fromData(DataReader(data)) {
                switch packet.type {
                    case .peerAdded: self.addPeer(packet.identifier)
                    case .peerRemoved: self.removePeer(packet.identifier)
                    case .connectionRequest: self.respondToConnectionRequest(packet.identifier)
                    default: log(.high, error: "Received unexpected packet type: \(packet.type.rawValue)")
                }
            } else {
                log(.high, error: "discovery packet could not be parsed.")
            }
        } else {
            log(.high, error: "message is not data.")
        }
    }
}
