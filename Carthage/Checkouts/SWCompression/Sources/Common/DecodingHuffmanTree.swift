// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class DecodingHuffmanTree {

    private let bitReader: BitReader

    private let tree: [Int]
    private let leafCount: Int

    /// `lengths` don't have to be properly sorted, but there must not be any 0 code lengths.
    init(lengths: [HuffmanLength], _ bitReader: BitReader) {
        self.bitReader = bitReader

        // Sort `lengths` array to calculate canonical Huffman code.
        let sortedLengths = lengths.sorted()

        // Calculate maximum amount of leaves possible in a tree.
        self.leafCount = 1 << (sortedLengths.last!.codeLength + 1)
        var tree = Array(repeating: -1, count: leafCount)

        // Calculates symbols for each length in 'sortedLengths' array and put them in the tree.
        var loopBits = -1
        var symbol = -1
        for length in sortedLengths {
            precondition(length.codeLength > 0, "Code length must not be 0 during HuffmanTree construction.")
            symbol += 1
            // We sometimes need to make symbol to have length.bits bit length.
            let bits = length.codeLength
            if bits != loopBits {
                symbol <<= (bits - loopBits)
                loopBits = bits
            }
            // Then we need to reverse bit order of the symbol.
            var treeCode = symbol.reversed(bits: loopBits)

            // Finally, we put it at its place in the tree.
            var index = 0
            for _ in 0..<bits {
                let bit = treeCode & 1
                index = bit == 0 ? 2 * index + 1 : 2 * index + 2
                treeCode >>= 1
            }
            tree[index] = length.symbol
        }
        self.tree = tree
    }

    func findNextSymbol() -> Int {
        var index = 0
        while true {
            let bit = bitReader.bit()
            index = bit == 0 ? 2 * index + 1 : 2 * index + 2
            guard index < self.leafCount
                else { return -1 }
            if self.tree[index] > -1 {
                return self.tree[index]
            }
        }
    }

}
