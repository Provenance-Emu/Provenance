//
//  CompositeAdvertiser.swift
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

/** A CompositeAdvertiser combines multiple Reto Advertisers into a single one. */
class CompositeAdvertiser: Advertiser, AdvertiserDelegate {
    var advertisers: [Advertiser]
    var localPeerIdentifier: UUID?
    var advertiserDelegate: AdvertiserDelegate?
    var isAdvertising: Bool = false

    init(advertisers: [Advertiser]) {
        self.advertisers = advertisers
        for advertiser in self.advertisers {
            advertiser.advertiserDelegate = self
        }
    }

    func startAdvertising(_ identifier: UUID) {
        self.localPeerIdentifier = identifier

        for advertiser in advertisers { advertiser.startAdvertising(identifier) }
        self.isAdvertising = true
    }

    func stopAdvertising() {
        for advertiser in advertisers { advertiser.stopAdvertising() }
    }

    func addAdvertiser(_ advertiser: Advertiser) {
        self.advertisers.append(advertiser)
        if self.isAdvertising { advertiser.startAdvertising(self.localPeerIdentifier!) }
    }

    func removeAdvertiser(_ advertiser: Advertiser) {
        self.advertisers = self.advertisers.filter({ $0 === advertiser})
        advertiser.stopAdvertising()
    }

    func didStartAdvertising(_ advertiser: Advertiser) {
        if self.advertisers.map({ $0.isAdvertising }).reduce(true, { $0 && $1 }) {
            self.advertiserDelegate?.didStartAdvertising(self)
        }
    }

    func didStopAdvertising(_ advertiser: Advertiser) {
        if self.advertisers.map({ !$0.isAdvertising }).reduce(true, { $0 && $1 }) {
            self.advertiserDelegate?.didStopAdvertising(self)
        }
    }

    func handleConnection(_ advertiser: Advertiser, connection underlyingConnection: UnderlyingConnection) {
        self.advertiserDelegate?.handleConnection(self, connection: underlyingConnection)
    }
}
