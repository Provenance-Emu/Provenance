// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

final class EncodingTree {

    private let bitWriter: BitWriter

    private let codingIndices: [[Int]]

    init(codes: [Code], _ bitWriter: BitWriter, reverseCodes: Bool = false) {
        self.bitWriter = bitWriter

        var codingIndices = Array(repeating: [-1, -1], count: codes.count)

        for code in codes {
            // Codes have already been reversed.
            // TODO: This assumption may be only correct for Huffman codes.
            let treeCode = reverseCodes ? code.code : code.code.reversed(bits: code.bits)
            codingIndices[code.symbol] = [treeCode, code.bits]
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
