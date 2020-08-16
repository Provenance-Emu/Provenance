// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that contains functions for writing `Data` bit-by-bit (and byte-by-byte).
public protocol BitWriter {

    /// Data which contains writer's output (the last byte in progress is not included).
    var data: Data { get }

    /// True, if writer's BIT pointer is aligned with the BYTE border.
    var isAligned: Bool { get }

    /// Creates an instance for writing bits (and bytes).
    init()

    /// Writes `bit`, advancing by one BIT position.
    func write(bit: UInt8)

    /// Writes `bits`, advancing by `bits.count` BIT positions.
    func write(bits: [UInt8])

    /// Writes `number`, using and advancing by `bitsCount` BIT positions.
    func write(number: Int, bitsCount: Int)

    /// Writes `byte`, advancing by one BYTE position.
    func append(byte: UInt8)

    /**
     Aligns writer's BIT pointer to the BYTE border, i.e. moves BIT pointer to the first BIT of the next BYTE,
     filling all skipped BIT positions with zeros.
     */
    func align()

}

extension BitWriter {

    public func write(bits: [UInt8]) {
        for bit in bits {
            self.write(bit: bit)
        }
    }

}
