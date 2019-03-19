//
//  BonjourBrowser.swift
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

protocol BonjourServiceBrowserDelegate : class {
    func foundAddress(_ identifier: UUID, addressInformation: AddressInformation)
    func removedAddress(_ identifier: UUID)
    func didStart()
    func didStop()
}

protocol BonjourServiceBrowser : class {
    weak var delegate: BonjourServiceBrowserDelegate? { get set }

    func startBrowsing(_ networkType: String)
    func stopBrowsing()
}

class BonjourBrowser: NSObject, Browser, BonjourServiceBrowserDelegate {
    let browser: BonjourServiceBrowser
    let networkType: String
    let dispatchQueue: DispatchQueue
    let recommendedPacketSize: Int
    var addresses: [UUID: Address] = [:]
    var browserDelegate: BrowserDelegate?
    var isBrowsing: Bool = false

    init(networkType: String, dispatchQueue: DispatchQueue, browser: BonjourServiceBrowser, recommendedPacketSize: Int) {
        self.networkType = networkType
        self.dispatchQueue = dispatchQueue
        self.browser = browser
        self.recommendedPacketSize = recommendedPacketSize
    }

    func startBrowsing() {
        if !self.isBrowsing {
            self.browser.delegate = self
            self.browser.startBrowsing(self.networkType)
        }
    }

    func stopBrowsing() {
        self.isBrowsing = false
        self.browser.stopBrowsing()
    }

    func didStart() {
        self.isBrowsing = true
        self.browserDelegate?.didStartBrowsing(self)
    }

    func didStop() {
        self.isBrowsing = false
        self.browserDelegate?.didStopBrowsing(self)
    }

    func foundAddress(_ identifier: UUID, addressInformation: AddressInformation) {
        let address = TcpIpAddress(dispatchQueue: self.dispatchQueue, address: addressInformation, recommendedPacketSize: self.recommendedPacketSize)
        self.addresses[identifier] = address
        self.browserDelegate?.didDiscoverAddress(self, address: address, identifier: identifier)
    }

    func removedAddress(_ identifier: UUID) {
        let addr = self.addresses[identifier]
        self.addresses[identifier] = nil

        if let addr = addr {
            self.browserDelegate?.didRemoveAddress(self, address: addr, identifier: identifier)
        }
    }
}
