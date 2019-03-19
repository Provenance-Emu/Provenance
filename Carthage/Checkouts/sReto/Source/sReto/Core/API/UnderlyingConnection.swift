//
//  UnderlyingConnection.swift
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

/** 
* The UnderlyingConnectionDelegate allows the UnderlyingConnection to inform its delegate about various events.
*/
public protocol UnderlyingConnectionDelegate : class {
    /** Called when the connection connected successfully.*/
    func didConnect(_ connection: UnderlyingConnection)
    /** Called when the connection closes. Has an optional error parameter to indicate issues. (Used to report problems to the user). */
    func didClose(_ connection: UnderlyingConnection, error: AnyObject?)
    /** Called when data was received. */
    func didReceiveData(_ connection: UnderlyingConnection, data: Data)
    /** 
    * Called for each writeData call, when it is complete.
    * Note: The current implementation of Reto does not work when this method is called directly from writeData. If you wish to call it immediately, use dispatch_async to call it.
    */
    func didSendData(_ connection: UnderlyingConnection)
}

/**
* An UnderlyingConnection is a Connection with the minimal necessary functionality that allows the implementation of Reto connections on top of it.
* It is called UnderlyingConnection to differentiate it from Reto's high-level Connection class, which offers many additional features.
* Reto's users don't interact with this class directly.
*/
public protocol UnderlyingConnection : class {
    /** The connection's delegate. */
    /*weak */var delegate : UnderlyingConnectionDelegate? { get set }
    /** Whether this connection is currently connected. */
    var isConnected : Bool { get }
    /** Reto sends packets which may vary in size. This property may return an ideal packet size that should be used if possible. */
    var recommendedPacketSize : Int { get }

    /** Connects the connection. */
    func connect()
    /** Closes the connection. */
    func close()
    /** Sends data using the connection. */
    func writeData(_ data : Data)
}
