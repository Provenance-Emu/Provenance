//
//  Address.swift
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
* An Address encapsulates the necessary information for the peer to establish a connection to another peer.
* Addresses are generated and distributed by an Advertiser. The Advertiser also ensures that the Address is functional by accepting connections.
* These advertised Addresses can then be discovered by Browsers.
*/
public protocol Address: class {
    /** The cost of an address gives an heuristic about which Address should be used if multiple are available. Lower cost is preferred. An WlanAddress uses a cost of 10. */ 
    var cost: Int { get }

    var hostName: String { get }
    /** 
    * Called to establish a new outgoing connection.
    * @return A new connection to the peer.
    */
    func createConnection() -> UnderlyingConnection
}
