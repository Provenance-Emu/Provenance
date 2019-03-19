//
//  ModuleManager.swift
//  sReto
//
//  Created by Julian Asamer on 13/08/14.
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
* A ManagedModule wraps a Modules browser and advertiser in their Managed classes, which automatically restart them if starting fails.
* */
class ManagedModule: Module {
    let module: Module

    override var description: String {
        return "ManagedModule: {\n\tadvertiser: \(self.advertiser), \n\tbrowser: \(self.browser)"
    }

    init(module: Module, dispatchQueue: DispatchQueue) {
        self.module = module
        let advertiser = ManagedAdvertiser(advertiser: module.advertiser, dispatchQueue: dispatchQueue)
        let browser = ManagedBrowser(browser: module.browser, dispatchQueue: dispatchQueue)
        module.dispatchQueue = dispatchQueue

        super.init(advertiser: advertiser, browser: browser)
    }
}

/**
* A ManagedAdvertiser automatically attempts to restart an Advertiser if starting the advertiser failed. The same concept applies to stopping the advertiser.
* */
class ManagedAdvertiser: NSObject, Advertiser, AdvertiserDelegate {
    let advertiser: Advertiser
    var startStopManager: StartStopHelper?
    var advertisedUuid: UUID?

    var advertiserDelegate: AdvertiserDelegate?
    var isAdvertising: Bool { get { return self.advertiser.isAdvertising } }

    override var description: String {
        return "ManagedAdvertiser: {isStarted: \(String(describing: self.startStopManager?.isStarted)), advertiser: \(advertiser)}"
    }

    init(advertiser: Advertiser, dispatchQueue: DispatchQueue) {
        self.advertiser = advertiser

        super.init()

        self.advertiser.advertiserDelegate = self
        self.startStopManager = StartStopHelper(
            startBlock: {
                [unowned self]
                attemptNumber in
                if let uuid = self.advertisedUuid {
                    if attemptNumber != 0 {
                        log(.low, info: "Trying to restart advertiser: \(advertiser). (Attempt #\(attemptNumber))")
                    }
                    advertiser.startAdvertising(uuid)
                }
            },
            stopBlock: {
                attemptNumber in
                if attemptNumber != 0 {
                    log(.low, info: "Trying to stop advertiser again: \(advertiser). (Attempt #\(attemptNumber))")
                }
                advertiser.stopAdvertising()
            },
            timerSettings: (initialInterval: 5, backOffFactor: 2, maximumDelay: 60),
            dispatchQueue: dispatchQueue
        )
    }

    func startAdvertising(_ identifier: UUID) {
        self.advertisedUuid = identifier
        self.startStopManager?.start()
    }

    func stopAdvertising() {
        self.startStopManager?.stop()
    }

    // - MARK: AdvertiserDelegate
    func didStartAdvertising(_ advertiser: Advertiser) {
        self.startStopManager?.confirmStartOccured()
        log(.low, info: "Started advertisement using \(advertiser)")
        self.advertiserDelegate?.didStartAdvertising(self)
    }

    func didStopAdvertising(_ advertiser: Advertiser) {
        self.startStopManager?.confirmStopOccured()
        self.advertiserDelegate?.didStopAdvertising(self)
    }

    func handleConnection(_ advertiser: Advertiser, connection: UnderlyingConnection) {
        self.advertiserDelegate?.handleConnection(self, connection: connection)
    }
}

/**
* A ManagedBrowser automatically attempts to restart a Browser if starting the browser failed. The same concept applies to stopping the Browser.
* */
class ManagedBrowser: NSObject, Browser, BrowserDelegate {
    let browser: Browser
    var browserDelegate: BrowserDelegate?
    var startStopManager: StartStopHelper?
    var isBrowsing: Bool { get { return self.browser.isBrowsing } }

    override var description: String {
        return "ManagedBrowser: {isStarted: \(String(describing: self.startStopManager?.isStarted)), browser: \(self.browser)"
    }

    init(browser: Browser, dispatchQueue: DispatchQueue) {
        self.browser = browser

        super.init()

        self.browser.browserDelegate = self
        self.startStopManager = StartStopHelper(
            startBlock: {
                [unowned self]
                attemptNumber in
                if attemptNumber != 0 {
                    log(.low, info: "Trying to restart browser: \(self.browser). (Attempt #\(attemptNumber))")
                }
                self.browser.startBrowsing()
            },
            stopBlock: {
                [unowned self]
                attemptNumber in
                if attemptNumber != 0 {
                    log(.low, info: "Trying to stop browser again: \(self.browser). (Attempt #\(attemptNumber))")
                }
                self.browser.stopBrowsing()
            },
            timerSettings: (initialInterval: 5, backOffFactor: 2, maximumDelay: 60),
            dispatchQueue: dispatchQueue
        )
    }

    func startBrowsing() {
        self.startStopManager?.start()
    }
    func stopBrowsing() {
        self.startStopManager?.stop()
    }

    func didStartBrowsing(_ browser: Browser) {
        self.startStopManager?.confirmStartOccured()
        self.browserDelegate?.didStartBrowsing(self)
        log(.low, info: "Started browsing using \(browser)")
    }

    func didStopBrowsing(_ browser: Browser) {
        self.startStopManager?.confirmStopOccured()
        self.browserDelegate?.didStopBrowsing(self)
    }

    func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.browserDelegate?.didDiscoverAddress(self, address: address, identifier: identifier)
    }

    func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.browserDelegate?.didRemoveAddress(self, address: address, identifier: identifier)
    }
}
