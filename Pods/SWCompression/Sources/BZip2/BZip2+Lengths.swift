// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

// BZip2 specific function for generation of HuffmanLength array from stats.
extension BZip2 {

    /**
     Based on "procedure for generating the lists which specify a Huffman code table" (annexes C and K)
     from Recommendation T.81 of ITU (aka JPEG specfications).
     */
    static func lengths(from stats: [Int]) -> [CodeLength] {
        // Handle redundant cases.
        if stats.count == 0 {
            return []
        } else if stats.count == 1 {
            return [CodeLength(symbol: 0, codeLength: 1)]
        }

        // Calculate code lengths based on stats.
        let codeLengths = calculateCodeLengths(from: stats)

        // Now we count code sizes.
        var bits = count(codeLengths)

        adjust(&bits)

        return generateSizeTable(from: bits)
    }

    private static func calculateCodeLengths(from stats: [Int]) -> [Int] {
        /// Mutable copy of input `stats`.
        var stats = stats

        var codeLengths = Array(repeating: 0, count: stats.count)
        var others = Array(repeating: -1, count: stats.count)

        while true {
            var c1 = -1
            var minFreq = Int.max
            for i in 0..<stats.count {
                if stats[i] > 0 && stats[i] <= minFreq {
                    minFreq = stats[i]
                    c1 = i
                }
            }

            var c2 = -1
            minFreq = Int.max
            for i in 0..<stats.count {
                if stats[i] > 0 && stats[i] <= minFreq && i != c1 {
                    minFreq = stats[i]
                    c2 = i
                }
            }

            guard c2 >= 0
                else { break }

            stats[c1] += stats[c2]
            stats[c2] = 0

            codeLengths[c1] += 1
            while others[c1] >= 0 {
                c1 = others[c1]
                codeLengths[c1] += 1

            }
            others[c1] = c2

            codeLengths[c2] += 1
            while others[c2] >= 0 {
                c2 = others[c2]
                codeLengths[c2] += 1
            }
        }
        return codeLengths
    }

    private static func count(_ codeLengths: [Int]) -> [Int] {
        var bits = Array(repeating: 0, count: codeLengths.count)
        for i in 0..<bits.count {
            // We don't check for zero code length because we have unused element in `bits` array for them.
            bits[codeLengths[i]] += 1
        }
        return bits
    }

    private static func adjust(_ bits: inout [Int]) {
        for i in stride(from: bits.count - 1, to: 20, by: -1) {
            while bits[i] > 0 {
                var j = i - 2
                while bits[j] == 0 {
                    j -= 1
                }
                bits[i] -= 2
                bits[i - 1] += 1
                bits[j + 1] += 2
                bits[j] -= 1
            }
        }
    }

    private static func generateSizeTable(from bits: [Int]) -> [CodeLength] {
        var symbol = 0
        var lengths = [CodeLength]()
        for i in 1...min(20, bits.count - 1) {
            var j = 1
            while j <= bits[i] {
                lengths.append(CodeLength(symbol: symbol, codeLength: i))
                symbol += 1
                j += 1
            }
        }
        return lengths
    }

}
