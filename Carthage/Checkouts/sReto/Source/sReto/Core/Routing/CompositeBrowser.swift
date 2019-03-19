//
//  CompositeBrowser.swift
//  sReto
//
//  Created by Julian Asamer on 22/07/14.
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

/** A CompositeBrowser combines multiple Reto Browsers into a single one. */
class CompositeBrowser: NSObject, Browser, BrowserDelegate {
    var browserDelegate : BrowserDelegate?
    var isBrowsing : Bool = false

    var browsers: [Browser] = []

    init(browsers: [Browser]) {
        self.browsers = browsers

        super.init()

        for browser in self.browsers {
            browser.browserDelegate = self
        }
    }

    func addBrowser(_ browser: Browser) {
        self.browsers.append(browser)
        if self.isBrowsing { browser.startBrowsing() }
    }

    func removeBrowser(_ browser: Browser) {
        self.browsers = self.browsers.filter({ $0 === browser})
        browser.stopBrowsing()
    }

    func startBrowsing() {
        self.isBrowsing = true
        for browser in self.browsers {
            browser.startBrowsing()
        }
    }

    func stopBrowsing() {
        self.isBrowsing = false
        for browser in self.browsers {
            browser.stopBrowsing()
        }
    }

    func didStartBrowsing(_ browser: Browser) {
        if self.browsers.map({ !$0.isBrowsing }).reduce(true, { $0 && $1 }) {
            self.browserDelegate?.didStopBrowsing(self)
        }
    }

    func didStopBrowsing(_ browser: Browser) {
        if self.browsers.map({ $0.isBrowsing }).reduce(true, { $0 && $1 }) {
            self.browserDelegate?.didStopBrowsing(self)
        }
    }

    func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.browserDelegate?.didDiscoverAddress(self, address: address, identifier: identifier)
    }

    func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID) {
        self.browserDelegate?.didRemoveAddress(self, address: address, identifier: identifier)
    }
}
