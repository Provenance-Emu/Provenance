// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

// Deflate specific functions for generation of HuffmanLength arrays from different inputs.
extension Deflate {

    // TODO: Make this work for both arrays and array slices.
    /// - Note: Skips zero codeLengths.
    static func lengths(from orderedCodeLengths: [Int]) -> [CodeLength] {
        var lengths = [CodeLength]()
        for (i, codeLength) in orderedCodeLengths.enumerated() where codeLength > 0 {
            lengths.append(CodeLength(symbol: i, codeLength: codeLength))
        }
        return lengths
    }

}
