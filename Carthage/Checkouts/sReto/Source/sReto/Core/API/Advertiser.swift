//
//  Advertiser.swift
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

/**
* The AdvertiserDelegate protocol allows the Advertiser to inform its delegate about various events.
*/
public protocol AdvertiserDelegate: class {
    /** Called when the advertiser started advertising. */
    func didStartAdvertising(_ advertiser: Advertiser)
    /** Called when the advertiser stopped advertising. */
    func didStopAdvertising(_ advertiser: Advertiser)
    /** Called when the advertiser received an incoming connection from a remote peer. */
    func handleConnection(_ advertiser: Advertiser, connection: UnderlyingConnection)
}

/** 
* An advertiser advertises the local peer, and allows other peers to establish connections to this peer.
*/
public protocol Advertiser: class {
    /** Whether the advertiser is currently active. */
    var isAdvertising: Bool { get }
    /** The Advertiser's delegate. */
    weak var advertiserDelegate: AdvertiserDelegate? { get set }

    /** 
    * Starts advertising.
    * @param identifier A UUID identifying the local peer.
    */
    func startAdvertising(_ identifier : UUID)
    /**
    * Stops advertising.
    */
    func stopAdvertising()
}
