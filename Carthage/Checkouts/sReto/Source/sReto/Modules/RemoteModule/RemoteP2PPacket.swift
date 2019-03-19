//
//  RemoteP2PPacket.swift
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

enum RemoteP2PPacketType: Int32 {
    case startAdvertisement = 1
    case stopAdvertisement = 2
    case startBrowsing = 3
    case stopBrowsing = 4
    case peerAdded = 5
    case peerRemoved = 6
    case connectionRequest = 7
}

struct RemoteP2PPacket {
    let type: RemoteP2PPacketType
    let identifier: UUID

    static func fromData(_ data: DataReader) -> RemoteP2PPacket? {
        let type = RemoteP2PPacketType(rawValue: data.getInteger())
        if type == nil { return nil }
        if !data.checkRemaining(16) { return nil }

        return RemoteP2PPacket(type: type!, identifier: data.getUUID())
    }

    func serialize() -> Data {
        let data = DataWriter(length: 20)
        data.add(self.type.rawValue)
        data.add(self.identifier)
        return data.getData() as Data
    }
}
