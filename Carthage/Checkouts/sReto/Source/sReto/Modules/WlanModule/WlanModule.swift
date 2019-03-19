//
//  WlanModule.swift
//  sReto
//
//  Created by Julian Asamer on 09/07/14.
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
* Using a WlanModule with the LocalPeer allows it to discover and connect with other peers on the local network using Bonjour.
*
* If you wish to use it, all you need to do is construct an instance and pass it to the LocalPeer either in the constructor or using the addModule method.
* */
open class WlanModule: Module {
    let networkType: String
    let recommendedPacketSize = 32*1024

    /**
    * Constructs a new WlanModule that can be used with a LocalPeer. 
    * @param type: Any ASCII string used to identify the type of application in the network. Can be anything, but should be unique for the application.
    * @param dispatchQueue: The dispatch queue used with this module. Use the same one as you used with the LocalPeer.
    */
    public init(type: String, dispatchQueue: DispatchQueue) {
        self.networkType = "_\(type)wlan._tcp."
        super.init(dispatchQueue: dispatchQueue)

        self.browser = BonjourBrowser(
            networkType: self.networkType,
            dispatchQueue: self.dispatchQueue,
            browser: WlanBonjourServiceBrowser(),
            recommendedPacketSize: self.recommendedPacketSize)

        self.advertiser = BonjourAdvertiser(
            networkType: self.networkType,
            dispatchQueue: self.dispatchQueue,
            advertiser: WlanBonjourServiceAdvertiser(),
            recommendedPacketSize: self.recommendedPacketSize)
    }
}
