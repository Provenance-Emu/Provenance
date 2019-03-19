//
//  UUID.swift
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

extension Foundation.UUID {
    init(uuid: UUID) {
        var uuidFoundation = uuid.uuidt
        self = NSUUID(uuidBytes: &uuidFoundation.0) as Foundation.UUID
    }
}

let UUID_T_ZERO: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
let UUID_ZERO: UUID = fromUUID_T(UUID_T_ZERO)

/** 
* This class represents unique universal identifiers, aka UUIDs.
* This class' primary purpose is to make the underlying byte array easier to access than the NSUUID class.
*/
public struct UUID: Comparable, Hashable, CustomStringConvertible {
    /** Stores the UUID as a 16 byte array */
    let uuid: [UInt8]
    public var hashValue: Int {
        return uuid.map { $0.hashValue }.enumerated().reduce(0, {
                let (index, hash) = $1
                return $0 ^ (hash << index * 2)
            }
        )
    }
    /** Returns the UUID as a uuid_t as defined by the Foundation framework */
    public var uuidt: uuid_t {
        return (
            uuid[ 0], uuid[ 1], uuid[ 2], uuid[ 3],
            uuid[ 4], uuid[ 5], uuid[ 6], uuid[ 7],
            uuid[ 8], uuid[ 9], uuid[10], uuid[11],
            uuid[12], uuid[13], uuid[14], uuid[15]
        )
    }

    /** Returns the string representation of this UUID */
    public var UUIDString: String {
        return Foundation.UUID(uuid: self).uuidString
    }

    public var description: String {
        return self.UUIDString
    }

    /** Constructs an UUID from a byte array. */
    public init(uuid: [UInt8]) {
        self.uuid = uuid
    }
}

/** Constructs a random UUID. */
public func randomUUID() -> UUID {
    return fromUUID(Foundation.UUID())
}

/** Converts an Foundation.UUID to a UUID. */
public func fromUUID(_ nsuuid: Foundation.UUID) -> UUID {
    var uuid: uuid_t = UUID_T_ZERO
    withUnsafeMutablePointer(to: &uuid.0, { pointer in (nsuuid as NSUUID).getBytes(pointer)})
    return fromUUID_T(uuid)
}

/** Converts an uuid_t to a UUID. */
public func fromUUID_T(_ uuid: uuid_t) -> UUID {
    return UUID(
        uuid: [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15
        ]
    )
}

/** Constructs an UUID from its string representation. */
public func UUIDfromString(_ string: String) -> UUID? {
    if let uuid = Foundation.UUID(uuidString: string) {
        return fromUUID(uuid)
    } else {
        return nil
    }
}

public func == (id1: UUID, id2: UUID) -> Bool {
    return id1.uuid == id2.uuid
}
/** Interprets the UUIDs as 16 byte integers to compare them. */
public func < (id1: UUID, id2: UUID) -> Bool {
    return id1.uuid < id2.uuid
}
