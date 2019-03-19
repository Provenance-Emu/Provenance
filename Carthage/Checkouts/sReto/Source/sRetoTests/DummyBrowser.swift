//
//  DummyBrowser.swift
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

class DummyBrowser: NSObject, Browser {
    let networkInterface: DummyNetworkInterface
    var browserDelegate: BrowserDelegate?
    var isBrowsing: Bool = false
    var addresses: [UUID: DummyAddress] = [:]

    init(networkInterface: DummyNetworkInterface) {
        self.networkInterface = networkInterface
    }

    func startBrowsing() {
        self.networkInterface.register(browser: self)
        self.isBrowsing = true
        DispatchQueue.main.async {
             if let delegate = self.browserDelegate { delegate.didStartBrowsing(self) }
        }
    }
    func stopBrowsing() {
        self.networkInterface.unregister(browser: self)
        self.isBrowsing = false
        DispatchQueue.main.async {
            if let delegate = self.browserDelegate { delegate.didStopBrowsing(self) }
        }
    }
    func onAddPeer(identifier: UUID, address: DummyAddress) {
        addresses[identifier] = address
        self.browserDelegate?.didDiscoverAddress(self, address: address, identifier: identifier)
    }
    func onRemovePeer(identifier: UUID) {
        self.browserDelegate?.didRemoveAddress(self, address: addresses[identifier]!, identifier: identifier)
        addresses[identifier] = nil
    }
}
