// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Used to decode symbols that need several bits for storing.
final class LZMABitTreeDecoder {

    var probs: [Int]
    let numBits: Int

    init(numBits: Int) {
        self.probs = Array(repeating: LZMAConstants.probInitValue,
                           count: 1 << numBits)
        self.numBits = numBits
    }

    func decode(with rangeDecoder: LZMARangeDecoder) -> Int {
        var m = 1
        for _ in 0..<self.numBits {
            m = (m << 1) + rangeDecoder.decode(bitWithProb: &self.probs[m])
        }
        return m - (1 << self.numBits)
    }

    func reverseDecode(with rangeDecoder: LZMARangeDecoder) -> Int {
        return LZMABitTreeDecoder.bitTreeReverseDecode(probs: &self.probs,
                                                       startIndex: 0,
                                                       bits: self.numBits, rangeDecoder)
    }

    static func bitTreeReverseDecode(probs: inout [Int], startIndex: Int, bits: Int,
                                     _ rangeDecoder: LZMARangeDecoder) -> Int {
        var m = 1
        var symbol = 0
        for i in 0..<bits {
            let bit = rangeDecoder.decode(bitWithProb: &probs[startIndex + m])
            m <<= 1
            m += bit
            symbol |= bit << i
        }
        return symbol
    }

}
