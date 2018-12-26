// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct HuffmanLength: Equatable {

    let symbol: Int
    let codeLength: Int

}

extension HuffmanLength: Comparable {

    static func < (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.codeLength == right.codeLength {
            return left.symbol < right.symbol
        } else {
            return left.codeLength < right.codeLength
        }
    }

}
