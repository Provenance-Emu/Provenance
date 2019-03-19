//
//  SingePacketReading.swift
//  sReto
//
//  Created by Julian Asamer on 15/08/14.
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
* Reads a single packet from an underlying connection asynchronously.
* @param connection The connection from which to read the data from.
* @param packetHandler A closure to call when the data was received.
* @param failBlock A closure to call when reading the packet failed for any reason.
*/
func readSinglePacket(connection: UnderlyingConnection, onPacket packetHandler: @escaping (DataReader) -> Void, onFail failBlock: @escaping () -> Void) -> SinglePacketReader {
    return readPackets(connection: connection, packetCount: 1, onPacket: packetHandler, onSuccess: {}, onFail: failBlock)
}

/**
* Reads a fixed number of packets from an underlying connection.
* @param connection The connection from which to read the data from.
* @param packetCount The number of packets to read.
* @param packetHandler A closure call whenever a packet is received. Is called packetCount times if successfull.
* @param onSuccess A closure to call when the specified number of packets was received.
* @param failBlock A closure to call when reading the packets failed for any reason.
*/
func readPackets(connection: UnderlyingConnection, packetCount: Int, onPacket packetHandler: @escaping (DataReader) -> Void, onSuccess successBlock: @escaping () -> Void, onFail failBlock: @escaping () -> Void) -> SinglePacketReader {
    return SinglePacketReader(connection: connection, packetCount: packetCount, onPacket: packetHandler, onSuccess: successBlock, onFail: failBlock)
}

class SinglePacketReader: NSObject, UnderlyingConnectionDelegate {
    var underlyingConnection: UnderlyingConnection?
    let packetCount: Int
    let packetHandler: (DataReader) -> Void
    let successBlock: () -> Void
    let failBlock: () -> Void
    var packetsReceived = 0
    init(connection: UnderlyingConnection, packetCount: Int, onPacket packetHandler: @escaping (DataReader) -> Void, onSuccess successBlock: @escaping () -> Void, onFail failBlock: @escaping () -> Void) {
        self.underlyingConnection = connection
        self.packetCount = packetCount
        self.packetHandler = packetHandler
        self.failBlock = failBlock
        self.successBlock = successBlock

        super.init()
        connection.delegate = self
    }

    func didConnect(_ connection: UnderlyingConnection) {
    }

    func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {
        self.underlyingConnection?.delegate = nil
        self.underlyingConnection = nil
        self.failBlock()
    }

    func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
        self.packetsReceived += 1

        if self.packetsReceived == self.packetCount {
            underlyingConnection?.delegate = nil
        }

        self.packetHandler(DataReader(data))

        if self.packetsReceived == self.packetCount {
            self.underlyingConnection = nil
            self.successBlock()
        }
    }

    func didSendData(_ connection: UnderlyingConnection) {
    }
}

/**
* Writes a single packet to an underlying connection.
*
* @param connection The connection to write the data to.
* @param packet The packet to write.
* @param successBlock A closure to call when the packet was written successfully.
* @param failBlock A closure to call when sending the data failed for any reason.
*/
func writeSinglePacket(connection: UnderlyingConnection, packet: Packet, onSuccess successBlock: @escaping () -> Void, onFail failBlock: @escaping () -> Void) -> SinglePacketWriter {
    return SinglePacketWriter(connection: connection, packet: packet, successBlock: successBlock, failBlock: failBlock)
}

class SinglePacketWriter: NSObject, UnderlyingConnectionDelegate {
    var underlyingConnection: UnderlyingConnection?
    let successBlock: () -> Void
    let failBlock: () -> Void
    let packet: Packet

    init(connection: UnderlyingConnection, packet: Packet, successBlock: @escaping () -> Void, failBlock: @escaping () -> Void) {
        self.underlyingConnection = connection
        self.successBlock = successBlock
        self.failBlock = failBlock
        self.packet = packet

        super.init()

        connection.delegate = self
        if connection.isConnected {
            self.underlyingConnection?.writeData(packet.serialize())
        } else {
            log(.medium, info: "Attempt to write before connected")
        }
    }

    func didConnect(_ connection: UnderlyingConnection) {
        self.underlyingConnection?.writeData(packet.serialize())
    }

    func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {
        self.underlyingConnection?.delegate = nil
        self.underlyingConnection = nil
        self.failBlock()
    }

    func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
    }

    func didSendData(_ connection: UnderlyingConnection) {
        self.underlyingConnection?.delegate = nil
        self.underlyingConnection = nil
        self.successBlock()
    }
}
