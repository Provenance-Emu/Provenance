// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 A type that contains functions for writing `Data` bit-by-bit (and byte-by-byte),
 assuming "MSB 0" bit numbering scheme.
 */
public final class MsbBitWriter: BitWriter {

    /// Data which contains writer's output (the last byte in progress is not included).
    public private(set) var data: Data = Data()

    private var bitMask: UInt8 = 128
    private var currentByte: UInt8 = 0

    /// True, if writer's BIT pointer is aligned with the BYTE border.
    public var isAligned: Bool {
        return self.bitMask == 128
    }

    /// Creates an instance for writing bits (and bytes).
    public init() { }

    /// Writes `bit`, advancing by one BIT position.
    public func write(bit: UInt8) {
        precondition(bit <= 1, "A bit must be either 0 or 1.")

        self.currentByte += self.bitMask * bit

        if self.bitMask == 1 {
            self.bitMask = 128
            self.data.append(self.currentByte)
            self.currentByte = 0
        } else {
            self.bitMask >>= 1
        }
    }

    /**
     Writes `number`, using and advancing by `bitsCount` BIT positions.

     - Note: If `bitsCount` is smaller than the actual amount of `number`'s bits than the `number` will be truncated to
     fit into `bitsCount` amount of bits.
     - Note: Bits of `number` are processed using the same bit-numbering scheme as of the writer (i.e. "MSB 0").
     */
    public func write(number: Int, bitsCount: Int) {
        var mask = 1 << (bitsCount - 1)
        for _ in 0..<bitsCount {
            self.write(bit: number & mask > 0 ? 1 : 0)
            mask >>= 1
        }
    }

    /**
     Writes `number`, using and advancing by `bitsCount` BIT positions.

     - Note: If `bitsCount` is smaller than the actual amount of `number`'s bits than the `number` will be truncated to
     fit into `bitsCount` amount of bits.
     - Note: Bits of `number` are processed using the same bit-numbering scheme as of the writer (i.e. "MSB 0").
     - Note: This method is especially useful when it is necessary to write an unsigned number which overflows and,
     thus, crashes when converting to an `Int` if `write(number:bitsCount:)` method is used.
     */
    public func write(unsignedNumber: UInt, bitsCount: Int) {
        var mask: UInt = 1 << (UInt(truncatingIfNeeded: bitsCount) - 1)
        for _ in 0..<bitsCount {
            self.write(bit: unsignedNumber & mask > 0 ? 1 : 0)
            mask >>= 1
        }
    }

    /**
     Writes `byte`, advancing by one BYTE position.

     - Precondition: Writer MUST be aligned.
     */
    public func append(byte: UInt8) {
        precondition(isAligned, "BitWriter is not aligned.")
        self.data.append(byte)
    }

    /**
     Aligns writer's BIT pointer to the BYTE border, i.e. moves BIT pointer to the first BIT of the next BYTE,
     filling all skipped BIT positions with zeros.

     - Note: If writer is already aligned, then does nothing.
     */
    public func align() {
        guard self.bitMask != 128
            else { return }

        self.data.append(self.currentByte)
        self.currentByte = 0
        self.bitMask = 128
    }

}
