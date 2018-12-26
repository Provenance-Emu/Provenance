// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class EncodingHuffmanTree {

    private let bitWriter: BitWriter

    private let codingIndices: [[Int]]

    /// `lengths` don't have to be properly sorted, but there must not be any 0 code lengths.
    /// If `reverseCodes` is true, then bit order of tree codes will be reversed. Necessary for Deflate.
    init(lengths: [HuffmanLength], _ bitWriter: BitWriter, reverseCodes: Bool = false) {
        self.bitWriter = bitWriter

        // Sort `lengths` array to calculate canonical Huffman code.
        let sortedLengths = lengths.sorted()

        var codingIndices = Array(repeating: [-1, -1], count: sortedLengths.count)

        // Calculates symbols for each length in 'sortedLengths' array and put them in the tree.
        var loopBits = -1
        var symbol = -1
        for length in sortedLengths {
            precondition(length.codeLength > 0, "Code length must not be 0 during HuffmanTree initialisation.")
            symbol += 1
            // We sometimes need to make symbol to have length.bits bit length.
            let bits = length.codeLength
            if bits != loopBits {
                symbol <<= (bits - loopBits)
                loopBits = bits
            }
            // Then we reverse bit order of the symbol, if necessary.
            let treeCode = reverseCodes ? symbol.reversed(bits: loopBits) : symbol
            codingIndices[length.symbol] = [treeCode, bits]
        }
        self.codingIndices = codingIndices
    }

    func code(symbol: Int) {
        guard symbol < self.codingIndices.count
            else { fatalError("Symbol is not found.") }

        let codingIndex = self.codingIndices[symbol]

        guard codingIndex[0] > -1
            else { fatalError("Symbol is not found.") }

        self.bitWriter.write(number: codingIndex[0], bitsCount: codingIndex[1])
    }

    func bitSize(for stats: [Int]) -> Int {
        var totalSize = 0
        for (symbol, count) in stats.enumerated() where count > 0 {
            guard symbol < self.codingIndices.count
                else { fatalError("Symbol is not found.") }
            let codingIndex = self.codingIndices[symbol]
            guard codingIndex[0] > -1
                else { fatalError("Symbol is not found.") }

            totalSize += count * codingIndex[1]
        }
        return totalSize
    }

}
