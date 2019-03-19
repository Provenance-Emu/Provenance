//
//  RemoteP2PConnection.swift
//  sReto
//
//  Created by Julian Asamer on 07/08/14.
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

class RemoteP2PConnection: NSObject, UnderlyingConnection {
    weak var delegate: UnderlyingConnectionDelegate?
    var isConnected: Bool = false
    var receivedConnectionConfirmation = false
    var recommendedPacketSize: Int = 2048
    var serverUrl: URL?
    let dispatchQueue: DispatchQueue
    var selfRetain: RemoteP2PConnection?

    var socket: SRWebSocket?

    override var description: String {
        return "RemoteP2PConnection: {url: \(String(describing: self.serverUrl)), isConnected: \(self.isConnected), webSocket: \(String(describing: self.socket))}"
    }

    init(serverUrl: URL, dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue

        super.init()

        self.serverUrl = serverUrl
        self.selfRetain = self
    }
    init(socket: SRWebSocket, dispatchQueue: DispatchQueue) {
        self.socket = socket
        self.dispatchQueue = dispatchQueue
        self.socket?.setDelegateDispatchQueue(dispatchQueue)
        self.isConnected = true
        self.receivedConnectionConfirmation = true
        super.init()
        self.selfRetain = self
        socket.delegate = self
    }

    func connect() {
        if let url = self.serverUrl {
            self.socket = SRWebSocket(url: url)
            self.socket?.setDelegateDispatchQueue(self.dispatchQueue)
            self.socket?.delegate = self
            self.socket?.open()
        }
    }
    func close() {
        self.socket?.close()
        self.socket = nil
    }
    func writeData(_ data: Data) {
        if !isConnected {
            log(.high, error: "Attempted to write data before connection connected.")
            return
        }

        self.socket?.send(data)
        self.dispatchQueue.async(execute: { () -> Void in
            self.delegate?.didSendData(self)
            return
        })
    }
}

extension RemoteP2PConnection: SRWebSocketDelegate {

    func webSocketDidOpen(_ webSocket: SRWebSocket!) {}

    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        log(.low, info: "closed web socket. Code: \(code), reason: \(reason), wasClean: \(wasClean)")

        if wasClean == true {
            self.delegate?.didClose(self, error: nil)
        } else {
            self.delegate?.didClose(self, error: "Code: \(code), reason: \(reason), wasClean: \(wasClean)" as AnyObject)
        }
    }

    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {

        log(.low, info: "closed with error: \(error)")

        self.delegate?.didClose(self, error: error as AnyObject?)
    }

    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let data = message as? Data {
            if !receivedConnectionConfirmation {
                let reader = DataReader(data)
                if !reader.checkRemaining(4) || reader.getInteger() != 1 {
                    log(.high, error: "Expected confirmation, other data received.")
                    self.close()
                    return
                } else {
                    self.receivedConnectionConfirmation = true
                    self.isConnected = true
                    self.delegate?.didConnect(self)
                }
            } else {
                self.delegate?.didReceiveData(self, data: data)
            }
        }
    }
}
