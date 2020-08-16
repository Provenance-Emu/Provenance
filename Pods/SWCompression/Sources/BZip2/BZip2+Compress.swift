// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension BZip2: CompressionAlgorithm {

    /**
     Compresses `data` with BZip2 algortihm.

     - Parameter data: Data to compress.

     - Note: Input data will be split into blocks of size 100 KB. Use `BZip2.compress(data:blockSize:)` function to
     specify the size of a block.
     */
    public static func compress(data: Data) -> Data {
        return compress(data: data, blockSize: .one)
    }

    private static let blockMarker: [UInt8] = [
        0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,
        0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0,
        0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1
    ]

    private static let eosMarker: [UInt8] = [
        0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0,
        0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0
    ]

    /**
     Compresses `data` with BZip2 algortihm, splitting data into blocks of specified `blockSize`.

     - Parameter data: Data to compress.
     - Parameter blockSize: Size of blocks in which `data` will be split.
     */
    public static func compress(data: Data, blockSize: BlockSize) -> Data {
        let bitWriter = MsbBitWriter()
        // We intentionally use smaller block size for compression to account for potential data size expansion
        //  after intial RLE, which seems to be not being expected by original BZip2 implementation.
        let rawBlockSize = blockSize.sizeInKilobytes * 800
        // BZip2 Header.
        bitWriter.write(number: 0x425a, bitsCount: 16) // Magic number = 'BZ'.
        bitWriter.write(number: 0x68, bitsCount: 8) // Version = 'h'.
        bitWriter.write(number: blockSize.headerByte, bitsCount: 8) // Block size.

        var totalCRC: UInt32 = 0
        for i in stride(from: data.startIndex, to: data.endIndex, by: rawBlockSize) {
            let blockData = data[i..<min(data.endIndex, i + rawBlockSize)]
            let blockCRC = CheckSums.bzip2CRC32(blockData)

            totalCRC = (totalCRC << 1) | (totalCRC >> 31)
            totalCRC ^= blockCRC

            // Start block header.
            bitWriter.write(bits: blockMarker) // Block magic number.
            bitWriter.write(number: blockCRC.toInt(), bitsCount: 32) // Block crc32.

            process(block: blockData, bitWriter)
        }

        // EOS magic number.
        bitWriter.write(bits: eosMarker)
        // Total crc32.
        bitWriter.write(number: totalCRC.toInt(), bitsCount: 32)

        bitWriter.align()
        return bitWriter.data
    }

    private static func process(block data: Data, _ bitWriter: MsbBitWriter) {
        var out = initialRle(data)

        var pointer = 0
        (out, pointer) = BurrowsWheeler.transform(bytes: out)

        let usedBytes = Set(out).sorted()
        out = mtf(out, characters: usedBytes)

        var maxSymbol = 0
        (out, maxSymbol) = rleOfMtf(out)

        // First, we analyze data and create Huffman trees and selectors.
        // Then we will perform encoding itself.
        // These are separate stages because all information about trees is stored at the beginning of the block,
        //  and it is hard to modify it later.
        var processed = 50
        var tables = [EncodingTree]()
        var tablesLengths = [[Int]]()
        var selectors = [Int]()

        // Algorithm for code lengths calculations skips any symbol with frequency equal to 0.
        // Unfortunately, we need such unused symbols in tree creation, so we cannot skip them.
        // To prevent skipping, we set default value of 1 for every symbol's frequency.
        var stats = Array(repeating: 1, count: maxSymbol + 2)

        for i in 0..<out.count {
            let symbol = out[i]
            stats[symbol] += 1
            processed -= 1
            if processed <= 0 || i == out.count - 1 {
                processed = 50

                // Let's find minimum possible sizes for our stats using existing tables.
                var minimumSize = Int.max
                var minimumSelector = -1
                for tableIndex in 0..<tables.count {
                    let bitSize = tables[tableIndex].bitSize(for: stats)
                    if bitSize < minimumSize {
                        minimumSize = bitSize
                        minimumSelector = tableIndex
                    }
                }

                // If we already have 6 tables, we cannot create more, thus we choose one of the existing tables.
                if tables.count == 6 {
                    selectors.append(minimumSelector)
                } else {
                    // Otherwise, let's create a new table and check if it gives us better results.
                    // First, we calculate code lengths and codes for our current stats.
                    let lengths = BZip2.lengths(from: stats)
                    let codes = Code.huffmanCodes(from: lengths)
                    // Then, using these codes, we create a new Huffman tree.
                    let table = EncodingTree(codes: codes.codes, bitWriter)
                    if table.bitSize(for: stats) < minimumSize {
                        tables.append(table)
                        tablesLengths.append(lengths.sorted { $0.symbol < $1.symbol }.map { $0.codeLength })
                        selectors.append(tables.count - 1)
                    } else {
                        selectors.append(minimumSelector)
                    }
                }

                // Clear stats.
                stats = Array(repeating: 1, count: maxSymbol + 2)
            }
        }

        // Format requires at least two tables to be present.
        // If we have only one, we add a duplicate of it.
        if tables.count == 1 {
            tables.append(tables[0])
            tablesLengths.append(tablesLengths[0])
        }

        // Now, we perform encoding itself.
        // But first, we need to finish block header.
        bitWriter.write(number: 0, bitsCount: 1) // "Randomized".
        bitWriter.write(number: pointer, bitsCount: 24) // Original pointer (from BWT).

        var usedMap = Array(repeating: UInt8(0), count: 16)
        for usedByte in usedBytes {
            guard usedByte <= 255
                else { fatalError("Incorrect used byte.") }
            usedMap[usedByte / 16] = 1
        }
        bitWriter.write(bits: usedMap)

        var usedBytesIndex = 0
        for i in 0..<16 {
            guard usedMap[i] == 1 else { continue }
            for j in 0..<16 {
                if usedBytesIndex < usedBytes.count && i * 16 + j == usedBytes[usedBytesIndex] {
                    bitWriter.write(bit: 1)
                    usedBytesIndex += 1
                } else {
                    bitWriter.write(bit: 0)
                }
            }
        }

        bitWriter.write(number: tables.count, bitsCount: 3)
        bitWriter.write(number: selectors.count, bitsCount: 15)

        let mtfSelectors = mtf(selectors, characters: Array(0..<selectors.count))
        for selector in mtfSelectors {
            guard selector <= 5
                else { fatalError("Incorrect selector.") }
            bitWriter.write(bits: Array(repeating: 1, count: selector))
            bitWriter.write(bit: 0)
        }

        // Delta bit lengths.
        for lengths in tablesLengths {
            // Starting length.
            var currentLength = lengths[0]
            bitWriter.write(number: currentLength, bitsCount: 5)
            for length in lengths {
                while currentLength != length {
                    bitWriter.write(bit: 1) // Alter length.
                    if currentLength > length {
                        bitWriter.write(bit: 1) // Decrement length.
                        currentLength -= 1
                    } else {
                        bitWriter.write(bit: 0) // Increment length.
                        currentLength += 1
                    }
                }
                bitWriter.write(bit: 0)
            }
        }

        // Contents.
        var encoded = 0
        var selectorPointer = 0
        var t: EncodingTree?
        for symbol in out {
            encoded -= 1
            if encoded <= 0 {
                encoded = 50
                if selectorPointer == selectors.count {
                    fatalError("Incorrect selector.")
                } else if selectorPointer < selectors.count {
                    t = tables[selectors[selectorPointer]]
                    selectorPointer += 1
                }
            }
            t?.code(symbol: symbol)
        }
    }

    /// Initial Run Length Encoding.
    private static func initialRle(_ data: Data) -> [Int] {
        var out = [Int]()
        var index = data.startIndex
        while index < data.endIndex {
            var runLength = 1
            while index + 1 < data.endIndex && data[index] == data[index + 1] && runLength < 255 {
                runLength += 1
                index += 1
            }
            let byte = data[index].toInt()
            for _ in 0..<min(4, runLength) {
                out.append(byte)
            }
            if runLength >= 4 {
                out.append(runLength - 4)
            }
            index += 1
        }
        return out
    }

    private static func mtf(_ array: [Int], characters: [Int]) -> [Int] {
        var out = [Int]()
        /// Mutable copy of `characters`.
        var dictionary = characters
        for i in 0..<array.count {
            let index = dictionary.firstIndex(of: array[i])!
            out.append(index)
            let old = dictionary.remove(at: index)
            dictionary.insert(old, at: 0)
        }
        return out
    }

    private static func rleOfMtf(_ array: [Int]) -> ([Int], Int) {
        var out = [Int]()
        var lengthOfZerosRun = 0
        var maxSymbol = 1
        for i in 0..<array.count {
            let byte = array[i]
            if byte == 0 {
                lengthOfZerosRun += 1
            }
            if (byte == 0 && i == array.count - 1) || byte != 0 {
                if lengthOfZerosRun > 0 {
                    let digitsNumber = Int(floor(log2(Double(lengthOfZerosRun) + 1)))
                    var remainder = lengthOfZerosRun
                    for _ in 0..<digitsNumber {
                        let quotient = Int(ceil(Double(remainder) / 2) - 1)
                        let digit = remainder - quotient * 2
                        if digit == 1 {
                            out.append(0)
                        } else {
                            out.append(1)
                        }
                        remainder = quotient
                    }
                    lengthOfZerosRun = 0
                }
            }
            if byte != 0 {
                let newSymbol = byte + 1
                // We add one because, 1 is used as RUNB.
                // We don't add two instead, because 0 is never encountered as separate symbol, without RUNA meaning.
                out.append(newSymbol)
                if newSymbol > maxSymbol {
                    maxSymbol = newSymbol
                }
            }
        }
        // Add 'end of stream' symbol.
        out.append(maxSymbol + 1)
        return (out, maxSymbol)
    }

}
