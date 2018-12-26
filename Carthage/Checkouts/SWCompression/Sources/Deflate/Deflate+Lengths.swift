// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

// Deflate specific functions for generation of HuffmanLength arrays from different inputs.
extension Deflate {

    static func lengths(from bootStrap: [(symbol: Int, codeLength: Int)]) -> [HuffmanLength] {
        // Fills the 'lengths' array with pairs of (symbol, codeLength) from a 'bootstrap'.
        var lengths = [HuffmanLength]()
        var start = bootStrap[0].symbol
        var bits = bootStrap[0].codeLength
        for pair in bootStrap[1..<bootStrap.count] {
            let finish = pair.symbol
            let endbits = pair.codeLength
            if bits > 0 {
                for i in start..<finish {
                    lengths.append(HuffmanLength(symbol: i, codeLength: bits))
                }
            }
            start = finish
            bits = endbits
        }
        return lengths
    }

    /// - Note: Skips zero codeLengths.
    static func lengths(from orderedCodeLengths: [Int]) -> [HuffmanLength] {
        var lengths = [HuffmanLength]()
        for (i, codeLength) in orderedCodeLengths.enumerated() where codeLength > 0 {
            lengths.append(HuffmanLength(symbol: i, codeLength: codeLength))
        }
        return lengths
    }

}
