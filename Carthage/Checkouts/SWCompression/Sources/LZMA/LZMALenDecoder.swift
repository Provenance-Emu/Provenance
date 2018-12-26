// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

final class LZMALenDecoder {

    private var choice: Int = LZMAConstants.probInitValue
    private var choice2: Int = LZMAConstants.probInitValue
    private var lowCoder: [LZMABitTreeDecoder] = []
    private var midCoder: [LZMABitTreeDecoder] = []
    private var highCoder: LZMABitTreeDecoder

    init() {
        self.highCoder = LZMABitTreeDecoder(numBits: 8)
        for _ in 0..<(1 << LZMAConstants.numPosBitsMax) {
            self.lowCoder.append(LZMABitTreeDecoder(numBits: 3))
            self.midCoder.append(LZMABitTreeDecoder(numBits: 3))
        }
    }

    /// Decodes zero-based match length.
    func decode(with rangeDecoder: LZMARangeDecoder, posState: Int) -> Int {
        // There can be one of three options.
        // We need one or two bits to find out which decoding scheme to use.
        // `choice` is used to decode first bit.
        // `choice2` is used to decode second bit.
        // If binary sequence starts with 0 then:
        if rangeDecoder.decode(bitWithProb: &self.choice) == 0 {
            return self.lowCoder[posState].decode(with: rangeDecoder)
        }
        // If binary sequence starts with 1 0 then:
        if rangeDecoder.decode(bitWithProb: &self.choice2) == 0 {
            return 8 + self.midCoder[posState].decode(with: rangeDecoder)
        }
        // If binary sequence starts with 1 1 then:
        return 16 + self.highCoder.decode(with: rangeDecoder)
    }

}
