//
//  Data.swift
//  sReto
//
//  Created by Julian Asamer on 10/07/14.
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
* Read primitive types from NSData.
* 
* Manages a position internally so that no position needs to be specified when reading data.
*/
open class DataReader {
    fileprivate let data : Data
    open fileprivate(set) var position : Int

    /** Constructs a DataReader from an NSData object. */
    public init(_ data : Data) {
        self.data = data
        self.position = 0
    }

    /**
    * Checks whether more than length bytes can still be read.
    * @param length The number of bytes to check
    * @return true if more than or equal to length bytes can still be read.
    */
    open func checkRemaining(_ length : Int) -> Bool {
        return self.position + length <= self.data.count
    }
    /**
    * The number of remaining bytes to be read.
    */
    open func remaining() -> Int {
        return self.data.count - self.position
    }
    /**
    * Asserts that a certain number of bytes can still be read.
    */
    open func assertRemaining(_ length : Int) {
        assert(checkRemaining(length), "There is not enough data left to read.")
    }
    /**
    * Resets the position to zero.
    */
    open func rewind() {
        self.position = 0
    }
    /**
    * Returns a given number of bytes as an NSData object.
    * @param length The length of the data that should be returned in bytes.
    * @return An NSData object with the specified length.
    */
    func getData(_ length : Int) -> Data {
        self.assertRemaining(length)
        //TODO: is this correct?
        let range = Range<Data.Index>(uncheckedBounds:(lower:position, upper: position + length))
        let data = self.data.subdata(in: range)
        self.position += length
        return data
    }
    /**
    * Returns all remaining data.
    */
    open func getData() -> Data {
        return self.getData(self.data.count - self.position)
    }
    /**
    * Returns the next byte.
    */
    open func getByte() -> UInt8 {
        var value : UInt8 = 0
        self.getAndAdvance(&value, length: MemoryLayout<UInt8>.size)
        return value
    }
    /** 
    * Returns the next 4 byte integer.
    */
    open func getInteger() -> Int32 {
        var value : Int32 = 0
        self.getAndAdvance(&value, length: MemoryLayout<Int32>.size)
        return value
    }
    /**
    * Returns the next 8 byte long.
    */
    open func getLong() -> Int64 {
        var value : Int64 = 0
        self.getAndAdvance(&value, length: MemoryLayout<Int64>.size)
        return value
    }
    /**
    * Reads an UUID.
    */
    open func getUUID() -> UUID {
        var uuid: [UInt8] = Array(repeating: 0, count: 16)

        for part in 1...2 { for byte in 1...8 { uuid[part*8-byte] = self.getByte() } }

        return UUID(uuid: uuid)
    }
    /**
    * Reads an NSUUID.
    */
    open func getNSUUID() -> Foundation.UUID {
        var uuidFoundation = getUUID().uuidt
        return withUnsafePointer(to: &uuidFoundation.0, {pointer in (NSUUID(uuidBytes: pointer ) as Foundation.UUID)})
    }
    /** Reads data and advances the position. */
    fileprivate func getAndAdvance(_ value : UnsafeMutableRawPointer, length : Int) {
        self.assertRemaining(length)
        (self.data as NSData).getBytes(value, range: NSRange(location: self.position, length: length))
        position += length
    }
}

/** Write primitive types to NSData */
open class DataWriter {
    let data: NSMutableData

    /** Constructs a data writer with a given length. */
    public init(length: Int) {
        self.data = NSMutableData(capacity: length)!
    }

    /** Returns all data that was written. */
    open func getData() -> Data {
        return self.data as Data
    }
    /** Appends an NSData object. */
    open func add(_ data: Data) {
        self.data.append(data)
    }
    /** Appends a byte */
    open func add(_ byte: UInt8) {
        var value = byte
        self.data.append(&value, length: MemoryLayout<Int8>.size)
    }
    /** Appends a 4 byte integer */
    open func add(_ integer: Int32) {
        var value = integer
        self.data.append(&value, length: MemoryLayout<Int32>.size)
    }
    /** Appends a 8 byte long */
    open func add(_ long: Int64) {
        var value = long
        self.data.append(&value, length: MemoryLayout<Int64>.size)
    }
    /** Appends an UUID */
    open func add(_ uuid: UUID) {
        for part in 1...2 {
            for byte in 1...8 {
                self.add(uuid.uuid[part*8-byte])
            }
        }
    }
    /** Appends an NSUUID */
    open func add(_ nsuuid: Foundation.UUID) {
        var uuid: uuid_t = UUID_T_ZERO
        withUnsafeMutablePointer(to: &uuid.0, { pointer in (nsuuid as NSUUID).getBytes(pointer)})
        self.add(fromUUID_T(uuid))
    }
}
