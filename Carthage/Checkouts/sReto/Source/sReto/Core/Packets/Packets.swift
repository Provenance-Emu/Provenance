//
//  Packets.swift
//  sReto
//
//  Created by Julian Asamer on 13/07/14.
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
* The first four bytes of any packet contains it's type, represented as an integer. The different types are declared in this enum.
* See the packet's definitions below for more information about each type.
*/
enum PacketType: Int32 {
    case unknown = 0

    // Routing Layer
    case linkHandshake = 1
    case multicastHandshake = 2
    case linkState = 3
    case floodPacket = 4
    case routedConnectionEstablishedConfirmation = 5

    // Connectivity
    case managedConnectionHandshake = 10
    case closeRequest = 11
    case closeAnnounce = 12
    case closeAcknowledge = 13

    // Data transmission
    case transferStarted = 20
    case dataPacket = 21
    case cancelledTransfer = 22
    case progressInformation = 23
}

/** 
* The Packet protocol requires packets to implement a serialize function.
* In general, packets offer a static deserialize method as well, this method is not part of this protocol.
*/
protocol Packet {
    func serialize() -> Data
}
/** A helper class that does some generic data verification. */
class Packets {
    /**
    * Verifies that the data (wrapped in a DataReader) has the expected packet type, and has the minimum required lenght (i.e. number of bytes).
    * @param data The data to check
    * @param expectedType The type the packet is expected to have
    * @param minimumLength The minimum length required for the packet to be valid
    * @return Whether the conditions are met
    */
    class func check(data: DataReader, expectedType: PacketType, minimumLength: Int) -> Bool {
        if !data.checkRemaining(minimumLength) {
            log(.high, error: "Could not parse, not enough data remaining (\(minimumLength) needed, \(data.remaining()) remaining).")
            return false
        }
        let type = data.getInteger()
        if type != expectedType.rawValue {
            log(.high, error: "Could not parse, invalid packet type: \(type)")
            return false
        }

        return true
    }
}

/**
* A ManagedConnectionHandshake is sent once a connection was established with another peer.
* It contains the connections unique identifier, which is used to decide whether the new underlying connection should be used 
* with an existing connection (e.g. in the case of a reconnect), or if a new Connection should be created.
*/
struct ManagedConnectionHandshake: Packet {
    static var type: PacketType {
        return PacketType.managedConnectionHandshake
    }
    static var length: Int {
        return MemoryLayout<Int32>.size + MemoryLayout<UUID>.size
    }

    let connectionIdentifier: UUID

    static func deserialize(_ data: DataReader) -> ManagedConnectionHandshake? {
        if !Packets.check(data: data, expectedType: type, minimumLength: length) {
            return nil
        }
        return ManagedConnectionHandshake(connectionIdentifier: data.getUUID())
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).length)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(self.connectionIdentifier)
        return data.getData() as Data
    }
}

/**
* A CloseRequest is sent to the Connection establisher if the destination of the Connection attempts to close it.
* The establisher is expected to respond with a CloseAnnounce packet.
*/
struct CloseRequest: Packet {
    static var type: PacketType { get { return PacketType.closeRequest } }
    static var length: Int { get { return MemoryLayout<Int32>.size } }

    static func deserialize(_ data: DataReader) -> CloseRequest? {
        if !Packets.check(data: data, expectedType: type, minimumLength: length) { return nil }
        return CloseRequest()
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).length)
        data.add(Swift.type(of: self).type.rawValue)
        return data.getData() as Data
    }
}
/**
* Announces that a connection will close. Sent by the Connection establisher.
*/
struct CloseAnnounce: Packet {
    static var type: PacketType { get { return PacketType.closeAnnounce } }
    static var length: Int { get { return MemoryLayout<Int32>.size } }

    static func deserialize(_ data: DataReader) -> CloseAnnounce? {
        if !Packets.check(data: data, expectedType: type, minimumLength: length) { return nil }
        return CloseAnnounce()
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).length)
        data.add(Swift.type(of: self).type.rawValue)
        return data.getData() as Data
    }
}
/** 
* Acknowledges that a Connection is about to close. Sent by all destinations of a Connection.
* Once the establisher has received all acknowledgements (if the Connection is not a multicast connection, it is only one acknowledgement),
* the underlying connection is closed.
*/
struct CloseAcknowledge: Packet {
    static var type: PacketType { get { return PacketType.closeAcknowledge } }
    static var length: Int { get { return MemoryLayout<Int32>.size } }

    let source: UUID

    static func deserialize(_ data: DataReader) -> CloseAcknowledge? {
        if !Packets.check(data: data, expectedType: type, minimumLength: length) { return nil }
        return CloseAcknowledge(source: data.getUUID())
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).length)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(source)
        return data.getData() as Data
    }
}

/**
* Sent when a transfer was cancelled by the sender of a data transfer, or sent when the cancellation of a transfer is requested by the receiver of the data transfer.
*/
struct CancelledTransferPacket: Packet {
    static var type: PacketType { get { return PacketType.cancelledTransfer } }
    static var length: Int { get { return MemoryLayout<Int32>.size + MemoryLayout<UUID>.size } }

    let transferIdentifier: UUID

    static func deserialize(_ data: DataReader) -> CancelledTransferPacket? {
        if !Packets.check(data: data, expectedType: type, minimumLength: length) { return nil }
        return CancelledTransferPacket(transferIdentifier: data.getUUID())
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).length)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(self.transferIdentifier)
        return data.getData() as Data
    }
}

/**
* A DataPacket sends the payload data of a transfer.
*/
struct DataPacket: Packet {
    static var type: PacketType { get { return PacketType.dataPacket } }
    static var minimumLength: Int { get { return MemoryLayout<Int32>.size } }

    let data: Data

    static func deserialize(_ data: DataReader) -> DataPacket? {
        if !Packets.check(data: data, expectedType: type, minimumLength: minimumLength) { return nil }
        return DataPacket(data: data.getData() as Data)
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).minimumLength + self.data.count)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(self.data)
        return data.getData() as Data
    }
}

/** 
* This packet is sent when a transfer was interrupted and can be resumed to ensure that any data that went missing is resent.
*/
struct ProgressInformation {
    static var minimumLength: Int { get { return MemoryLayout<UUID>.size + MemoryLayout<Int32>.size } }
    let transferIdentifier: UUID
    let progress: Int32
}

struct ProgressInformationPacket: Packet {
    static var type: PacketType { get { return PacketType.progressInformation } }
    static var minimumLength: Int { get { return MemoryLayout<Int32>.size } }

    let information: [ProgressInformation]

    static func deserialize(_ data: DataReader) -> ProgressInformationPacket? {
        if !Packets.check(data: data, expectedType: type, minimumLength: minimumLength) { return nil }

        return ProgressInformationPacket(
            information: Array(0..<data.getInteger()).map {
                _ in ProgressInformation(transferIdentifier: data.getUUID(), progress: data.getInteger())
            }
        )
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).minimumLength + ProgressInformation.minimumLength * self.information.count)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(Int32(self.information.count))

        for progressInfo in self.information {
            data.add(progressInfo.transferIdentifier)
            data.add(progressInfo.progress)
        }

        return data.getData() as Data
    }
}

/**
* Sent when a new transfer is started.
*/
struct StartedTransferPacket: Packet {
    static var type: PacketType { get { return PacketType.transferStarted } }
    static var minimumLength: Int { get { return MemoryLayout<Int32>.size*2 + MemoryLayout<UUID>.size } }

    let transferIdentifier: UUID
    let transferLength: Int32

    static func deserialize(_ data: DataReader) -> StartedTransferPacket? {
        if !Packets.check(data: data, expectedType: type, minimumLength: minimumLength) { return nil }
        return StartedTransferPacket(transferIdentifier: data.getUUID(), transferLength: data.getInteger())
    }

    func serialize() -> Data {
        let data = DataWriter(length: Swift.type(of: self).minimumLength)
        data.add(Swift.type(of: self).type.rawValue)
        data.add(self.transferIdentifier)
        data.add(self.transferLength)
        return data.getData() as Data
    }
}
