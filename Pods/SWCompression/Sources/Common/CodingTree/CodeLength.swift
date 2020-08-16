// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct CodeLength: Equatable {

    let symbol: Int
    let codeLength: Int

    static func lengths(from bootstrap: [(symbol: Int, codeLength: Int)]) -> [CodeLength] {
        // Fills the 'lengths' array with pairs of (symbol, codeLength) from a 'bootstrap'.
        var lengths = [CodeLength]()
        var start = bootstrap[0].symbol
        var bits = bootstrap[0].codeLength
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair.symbol
            let endbits = pair.codeLength
            if bits > 0 {
                for i in start..<finish {
                    lengths.append(CodeLength(symbol: i, codeLength: bits))
                }
            }
            start = finish
            bits = endbits
        }
        return lengths
    }

}

extension CodeLength: Comparable {

    static func < (left: CodeLength, right: CodeLength) -> Bool {
        if left.codeLength == right.codeLength {
            return left.symbol < right.symbol
        } else {
            return left.codeLength < right.codeLength
        }
    }

}
