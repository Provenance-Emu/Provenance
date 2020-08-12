// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that contains functions for reading `Data` bit-by-bit and byte-by-byte, assuming "LSB0" bit numbering scheme.
public final class LsbBitReader: ByteReader, BitReader {

    private var bitMask: UInt8 = 1
    private var currentByte: UInt8

    /// True, if reader's BIT pointer is aligned with the BYTE border.
    public var isAligned: Bool {
        return self.bitMask == 1
    }

    /// Amount of bits left to read.
    public var bitsLeft: Int {
        return self.bytesLeft * 8 - self.bitMask.trailingZeroBitCount
    }

    /// Amount of bits that were already read.
    public var bitsRead: Int {
        return self.bytesRead * 8 + self.bitMask.trailingZeroBitCount
    }

    /// Creates an instance for reading bits (and bytes) from `data`.
    public override init(data: Data) {
        self.currentByte = data.first ?? 0
        super.init(data: data)
    }

    /**
     Converts a `ByteReader` instance into `LsbBitReader`, enabling bit reading capabilities. Current `offset` value of
     `byteReader` is preserved.
     */
    public init(_ byteReader: ByteReader) {
        self.currentByte = byteReader.isFinished ? 0 : byteReader.data[byteReader.offset]
        super.init(data: byteReader.data)
        self.offset = byteReader.offset
    }

    /**
     Advances reader's BIT pointer by specified amount of bits (default is 1).

     - Warning: Doesn't check if there is any data left. It is advised to use `isFinished` AFTER calling this method
     to check if the end was reached.
     */
    public func advance(by count: Int = 1) {
        for _ in 0..<count {
            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }
    }

    /**
     Reads bit and returns it, advancing by one BIT position.

     - Precondition: There MUST be enough data left.
     */
    public func bit() -> UInt8 {
        precondition(bitsLeft >= 1)
        let bit: UInt8 = self.currentByte & self.bitMask > 0 ? 1 : 0

        if self.bitMask == 128 {
            self.offset += 1
            self.bitMask = 1
        } else {
            self.bitMask <<= 1
        }

        return bit
    }

    /**
     Reads `count` bits and returns them as an array of `UInt8`, advancing by `count` BIT positions.

     - Precondition: Parameter `count` MUST not be less than 0.
     - Precondition: There MUST be enough data left.
     */
    public func bits(count: Int) -> [UInt8] {
        precondition(count >= 0)
        precondition(bitsLeft >= count)

        var array = [UInt8]()
        array.reserveCapacity(count)
        for _ in 0..<count {
            array.append(self.bit())
        }

        return array
    }

    /**
     Reads `fromBits` bits and returns them as an `Int` number, advancing by `fromBits` BIT positions.

     - Precondition: Parameter `fromBits` MUST be from `0...Int.bitWidth` range, i.e. it MUST not exceed maximum bit
     width of `Int` type on the current platform.
     - Precondition: There MUST be enough data left.
     */
    public func int(fromBits count: Int) -> Int {
        precondition(0...Int.bitWidth ~= count)
        precondition(bitsLeft >= count)

        var result = 0
        for i in 0..<count {
            let bit = self.currentByte & self.bitMask > 0 ? 1 : 0
            result += (1 << i) * bit

            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }

        return result
    }

    /**
     Reads `fromBits` bits and returns them as an `UInt8` number, advancing by `fromBits` BIT positions.

     - Precondition: Parameter `fromBits` MUST be from `0...8` range, i.e. it MUST not exceed maximum bit width of
     `UInt8` type on the current platform.
     - Precondition: There MUST be enough data left.
     */
    public func byte(fromBits count: Int) -> UInt8 {
        precondition(0...8 ~= count)
        precondition(bitsLeft >= count)

        var result = 0 as UInt8
        for i in 0..<count {
            let bit: UInt8 = self.currentByte & self.bitMask > 0 ? 1 : 0
            result += (1 << i) * bit

            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }

        return result
    }

    /**
     Reads `fromBits` bits and returns them as an `UInt16` number, advancing by `fromBits` BIT positions.

     - Precondition: Parameter `fromBits` MUST be from `0...16` range, i.e. it MUST not exceed maximum bit width of
     `UInt16` type on the current platform.
     - Precondition: There MUST be enough data left.
     */
    public func uint16(fromBits count: Int) -> UInt16 {
        precondition(0...16 ~= count)
        precondition(bitsLeft >= count)

        var result = 0 as UInt16
        for i in 0..<count {
            let bit: UInt16 = self.currentByte & self.bitMask > 0 ? 1 : 0
            result += (1 << i) * bit

            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }

        return result
    }

    /**
     Reads `fromBits` bits and returns them as an `UInt32` number, advancing by `fromBits` BIT positions.

     - Precondition: Parameter `fromBits` MUST be from `0...32` range, i.e. it MUST not exceed maximum bit width of
     `UInt32` type on the current platform.
     - Precondition: There MUST be enough data left.
     */
    public func uint32(fromBits count: Int) -> UInt32 {
        precondition(0...32 ~= count)
        precondition(bitsLeft >= count)

        var result = 0 as UInt32
        for i in 0..<count {
            let bit: UInt32 = self.currentByte & self.bitMask > 0 ? 1 : 0
            result += (1 << i) * bit

            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }

        return result
    }

    /**
     Reads `fromBits` bits and returns them as an `UInt64` number, advancing by `fromBits` BIT positions.

     - Precondition: Parameter `fromBits` MUST be from `0...64` range, i.e. it MUST not exceed maximum bit width of
     `UInt64` type on the current platform.
     - Precondition: There MUST be enough data left.
     */
    public func uint64(fromBits count: Int) -> UInt64 {
        precondition(0...64 ~= count)
        precondition(bitsLeft >= count)

        var result = 0 as UInt64
        for i in 0..<count {
            let bit: UInt64 = self.currentByte & self.bitMask > 0 ? 1 : 0
            result += (1 << i) * bit

            if self.bitMask == 128 {
                self.offset += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        }

        return result
    }

    /**
     Aligns reader's BIT pointer to the BYTE border, i.e. moves BIT pointer to the first BIT of the next BYTE.

     - Note: If reader is already aligned, then does nothing.
     - Warning: Doesn't check if there is any data left. It is advised to use `isFinished` AFTER calling this method
     to check if the end was reached.
     */
    public func align() {
        guard self.bitMask != 1
            else { return }

        self.bitMask = 1
        self.offset += 1
    }

    // MARK: ByteReader's methods.

    /**
     Offset to the byte in `data` which will be read next.

     - Note: The byte which is currently used for reading bits from is included into `bytesRead`.
     */
    public override var offset: Int {
        didSet {
            if !self.isFinished {
                { (data: Data, offset: Int, currentByte: inout UInt8) in
                    currentByte = data[offset]
                } (self.data, self.offset, &self.currentByte)
            }
        }
    }

    /**
     Reads byte and returns it, advancing by one BYTE position.

     - Precondition: Reader MUST be aligned.
     - Precondition: There MUST be enough data left.
     */
    public override func byte() -> UInt8 {
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt8 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(offset < data.endIndex)
            defer { offset += 1 }
            return data[offset]
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads `count` bytes and returns them as an array of `UInt8`, advancing by `count` BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: There MUST be enough data left.
     */
    public override func bytes(count: Int) -> [UInt8] {
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> [UInt8] in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= count)
            defer { offset += count }
            return data[offset..<offset + count].toByteArray(count)
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads `fromBytes` bytes and returns them as an `Int` number, advancing by `fromBytes` BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: Parameter `fromBytes` MUST not be less than 0.
     - Precondition: There MUST be enough data left.
     */
    public override func int(fromBytes count: Int) -> Int {
        precondition(count >= 0)
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> Int in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= count)
            var result = 0
            for i in 0..<count {
                result += Int(truncatingIfNeeded: data[offset]) << (8 * i)
                offset += 1
            }
            return result
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads 8 bytes and returns them as a `UInt64` number, advancing by 8 BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: There MUST be enough data left.
     */
    public override func uint64() -> UInt64 {
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt64 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= 8)
            defer { offset += 8 }
            return data[offset..<offset + 8].toU64()
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads `fromBytes` bytes and returns them as a `UInt64` number, advancing by `fromBytes` BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: Parameter `fromBytes` MUST not be less than 0.
     - Precondition: There MUST be enough data left.
     */
    public override func uint64(fromBytes count: Int) -> UInt64 {
        precondition(0...8 ~= count)
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt64 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= count)
            var result = 0 as UInt64
            for i in 0..<count {
                result += UInt64(truncatingIfNeeded: data[offset]) << (8 * i)
                offset += 1
            }
            return result
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads 4 bytes and returns them as a `UInt32` number, advancing by 4 BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: There MUST be enough data left.
     */
    public override func uint32() -> UInt32 {
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt32 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= 4)
            defer { offset += 4 }
            return data[offset..<offset + 4].toU32()
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads `fromBytes` bytes and returns them as a `UInt32` number, advancing by `fromBytes` BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: Parameter `fromBytes` MUST not be less than 0.
     - Precondition: There MUST be enough data left.
     */
    public override func uint32(fromBytes count: Int) -> UInt32 {
        precondition(0...4 ~= count)
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt32 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= count)
            var result = 0 as UInt32
            for i in 0..<count {
                result += UInt32(truncatingIfNeeded: data[offset]) << (8 * i)
                offset += 1
            }
            return result
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads 2 bytes and returns them as a `UInt16` number, advancing by 2 BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: There MUST be enough data left.
     */
    public override func uint16() -> UInt16 {
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt16 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= 2)
            defer { offset += 2 }
            return data[offset..<offset + 2].toU16()
        } (self.data, &self.offset, self.bitMask)
    }

    /**
     Reads `fromBytes` bytes and returns them as a `UInt16` number, advancing by `fromBytes` BYTE positions.

     - Precondition: Reader MUST be aligned.
     - Precondition: Parameter `fromBytes` MUST not be less than 0.
     - Precondition: There MUST be enough data left.
     */
    public override func uint16(fromBytes count: Int) -> UInt16 {
        precondition(0...2 ~= count)
        return { (data: Data, offset: inout Int, bitMask: UInt8) -> UInt16 in
            precondition(bitMask == 1, "BitReader is not aligned.")
            precondition(data.endIndex - offset >= count)
            var result = 0 as UInt16
            for i in 0..<count {
                result += UInt16(truncatingIfNeeded: data[offset]) << (8 * i)
                offset += 1
            }
            return result
        } (self.data, &self.offset, self.bitMask)
    }

}
