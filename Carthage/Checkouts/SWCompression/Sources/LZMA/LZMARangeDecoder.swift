// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

final class LZMARangeDecoder {

    private var byteReader: ByteReader

    private var range = 0xFFFFFFFF as UInt32
    private var code = 0 as UInt32
    private(set) var isCorrupted = false

    var isFinishedOK: Bool {
        return self.code == 0
    }

    init?(_ byteReader: ByteReader) {
        self.byteReader = byteReader

        let byte = self.byteReader.byte()
        for _ in 0..<4 {
            self.code = (self.code << 8) | UInt32(self.byteReader.byte())
        }
        if byte != 0 || self.code == self.range {
            return nil
        }
    }

    init() {
        self.byteReader = ByteReader(data: Data())
    }

    /// `range` property cannot be smaller than `(1 << 24)`. This function keeps it bigger.
    func normalize() {
        if self.range < UInt32(LZMAConstants.topValue) {
            self.range <<= 8
            self.code = (self.code << 8) | UInt32(byteReader.byte())
        }
    }

    /// Decodes sequence of direct bits (binary symbols with fixed and equal probabilities).
    func decode(directBits: Int) -> Int {
        var res: UInt32 = 0
        var count = directBits
        repeat {
            self.range >>= 1
            self.code = self.code &- self.range
            let t = 0 &- (self.code >> 31)
            self.code = self.code &+ (self.range & t)

            if self.code == self.range {
                self.isCorrupted = true
            }

            self.normalize()

            res <<= 1
            res = res &+ (t &+ 1)
            count -= 1
        } while count > 0
        return res.toInt()
    }

    /// Decodes binary symbol (bit) with predicted (estimated) probability.
    func decode(bitWithProb prob: inout Int) -> Int {
        let bound = (self.range >> UInt32(LZMAConstants.numBitModelTotalBits)) * UInt32(prob)
        let symbol: Int
        if self.code < bound {
            prob += ((1 << LZMAConstants.numBitModelTotalBits) - prob) >> LZMAConstants.numMoveBits
            self.range = bound
            symbol = 0
        } else {
            prob -= prob >> LZMAConstants.numMoveBits
            self.code -= bound
            self.range -= bound
            symbol = 1
        }
        self.normalize()
        return symbol
    }

}
