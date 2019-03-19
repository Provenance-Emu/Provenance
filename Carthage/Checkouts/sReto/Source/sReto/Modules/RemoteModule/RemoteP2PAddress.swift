//
//  RemoteP2PAddress.swift
//  sReto
//
//  Created by Julian Asamer on 07/08/14.
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

class RemoteP2PAddress: NSObject, Address {
    let serverUrl: URL
    let cost = 50
    let hostName: String

    override var description: String {
        return "RemoteP2PAddress: {url: \(self.serverUrl)}"
    }

    let dispatchQueue: DispatchQueue

    init(serverUrl: URL, dispatchQueue: DispatchQueue) {
        self.hostName = serverUrl.absoluteString
        self.serverUrl = serverUrl
        self.dispatchQueue = dispatchQueue
    }

    func createConnection() -> UnderlyingConnection {
        return RemoteP2PConnection(serverUrl: serverUrl, dispatchQueue: dispatchQueue)
    }
}
