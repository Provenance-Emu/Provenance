//
//  Browser.swift
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
* The BrowserDelegate protocol allows an implementation of the Browser protocol to inform it's delegate about various events.
*/
public protocol BrowserDelegate: class {
    /** Called when the Browser started to browse. */
    func didStartBrowsing(_ browser: Browser)
    /** Called when the Browser stopped to browse. */
    func didStopBrowsing(_ browser: Browser)
    /** Called when the Browser discovered an address. */
    func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID)
    /** Called when the Browser lost an address, i.e. when that address becomes invalid for any reason. */
    func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID)
}

/** A Browser attempts to discover other peers, it is the counterpart to the same module's advertiser. */
public protocol Browser: class {
    /** Whether the Browser is currently active. */
    var isBrowsing: Bool { get }
    /** The Browser's delegate */
    var browserDelegate: BrowserDelegate? { get set }

    /** Starts browsing for other peers. */
    func startBrowsing()
    /** Stops browsing for other peers. */
    func stopBrowsing()
}
