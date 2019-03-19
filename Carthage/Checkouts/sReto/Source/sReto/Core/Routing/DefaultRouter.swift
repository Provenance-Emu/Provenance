//
//  DefaultRouter.swift
//  sReto
//
//  Created by Julian Asamer on 12/08/14.
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

/** A DefaultRouter uses Reto Modules to discover other peers. */
class DefaultRouter: Router, AdvertiserDelegate, BrowserDelegate {
    let advertiser: CompositeAdvertiser
    let browser: CompositeBrowser
    var modules: [ManagedModule]

    init(localIdentifier: UUID, localName: String, dispatchQueue: DispatchQueue, modules: [Module]) {
        self.modules = modules.map { ManagedModule(module: $0, dispatchQueue: dispatchQueue) }
        self.advertiser = CompositeAdvertiser(advertisers: self.modules.map { $0.advertiser })
        self.browser = CompositeBrowser(browsers: self.modules.map { $0.browser })

        super.init(identifier: localIdentifier, name: localName, dispatchQueue: dispatchQueue)

        self.advertiser.advertiserDelegate = self
        self.browser.browserDelegate = self
    }

    func start() {
        self.advertiser.startAdvertising(self.identifier)
        self.browser.startBrowsing()
    }

    func stop() {
        self.advertiser.stopAdvertising()
        self.browser.stopBrowsing()
    }

    func addModule(_ module: Module) {
        let newModule = ManagedModule(module: module, dispatchQueue: self.dispatchQueue)

        self.advertiser.addAdvertiser(newModule.advertiser)
        self.browser.addBrowser(newModule.browser)
        self.modules.append(newModule)
    }

    func removeModule(_ module: Module) {
        let removedModules = self.modules.filter { $0.module === module }

        for removedModule in removedModules {
            self.advertiser.removeAdvertiser(removedModule.advertiser)
            self.browser.removeBrowser(removedModule.browser)
        }

        self.modules = self.modules.filter { $0.module !== module }
    }

    func didStartAdvertising(_ advertiser: Advertiser) {}
    func didStopAdvertising(_ advertiser: Advertiser) {}
    func handleConnection(_ advertiser: Advertiser, connection underlyingConnection: UnderlyingConnection) {
        self.handleDirectConnection(underlyingConnection)
    }
    func didStartBrowsing(_ browser: Browser) {}
    func didStopBrowsing(_ browser: Browser) {}
    func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.addAddress(identifier, nodeName: address.hostName, address: address)
    }
    func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.removeAddress(identifier, nodeName: nil, address: address)
    }
}
