//
//  WlanBonjourServiceBrowser.swift
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

class WlanBonjourServiceBrowser: NSObject, BonjourServiceBrowser, NetServiceBrowserDelegate, NetServiceDelegate {
    weak var delegate: BonjourServiceBrowserDelegate?
    var browser: NetServiceBrowser?
    var resolvingServices: [NetService] = []

    func startBrowsing(_ networkType: String) {
        let browser = NetServiceBrowser()
        self.browser = browser
        browser.delegate = self
        if #available(OSX 10.10, *) {
            browser.includesPeerToPeer = true
        } else {
            // Fallback on earlier versions
        }
        browser.searchForServices(ofType: networkType, inDomain: "")
    }

    func stopBrowsing() {
        if let browser = self.browser {
            browser.stop()
            browser.delegate = nil
            self.browser = nil
        }

        self.delegate?.didStop()
    }

    func addAddress(_ netService: NetService) {
        if let addresses = netService.addresses {
           log(.low, info: "found address for: \(netService.name), there are \(addresses.count) addresses available.")
            if let uuid = UUIDfromString(netService.name) {
                let addressInformation = AddressInformation.hostName(netService.hostName!, netService.port)
                self.delegate?.foundAddress(uuid, addressInformation: addressInformation)
            }
        }
    }

    func netServiceBrowserWillSearch(_ netServiceBrowser: NetServiceBrowser) {
        self.delegate?.didStart()
    }

    func netServiceBrowserDidStopSearch(_ netServiceBrowser: NetServiceBrowser) {
        self.delegate?.didStop()
    }

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didFind netService: NetService, moreComing: Bool) {
        if ((netService.addresses?.count ?? 0) != 0) {
            self.addAddress(netService)
        } else {
            netService.delegate = self
            self.resolvingServices.append(netService)
            netService.resolve(withTimeout: 5)
        }
    }

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didRemove netService: NetService, moreComing: Bool) {
        netService.delegate = nil
        if let uuid = UUIDfromString(netService.name) {
            self.delegate?.removedAddress(uuid)
        }
    }

    func netServiceDidResolveAddress(_ netService: NetService) {
        if (netService.addresses?.count ?? 0) != 0 {
            netService.delegate = nil
            self.addAddress(netService)
        } else {
            log(.low, info: "no addresses found.")
        }
    }

    func netService(_ netService: NetService, didNotResolve errorDict: [String : NSNumber]) {
        netService.delegate = nil
        log(.high, error: "Could not resolve net service. (\(errorDict))")
    }
}
