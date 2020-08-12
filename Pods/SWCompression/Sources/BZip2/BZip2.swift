// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for compression and decompression for BZip2 algorithm.
public class BZip2: DecompressionAlgorithm {

    /**
     Decompresses `data` using BZip2 algortihm.

     - Parameter data: Data compressed with BZip2.

     - Throws: `BZip2Error` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with BZip2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let bitReader = MsbBitReader(data: data)
        return try decompress(bitReader)
    }

    static func decompress(_ bitReader: MsbBitReader) throws -> Data {
        /// An array for storing output data
        var out = Data()

        let magic = bitReader.uint16()
        guard magic == 0x5a42 else { throw BZip2Error.wrongMagic }

        let method = bitReader.byte()
        guard method == 104 else { throw BZip2Error.wrongVersion }

        guard let blockSize = BlockSize(bitReader.byte())
            else { throw BZip2Error.wrongBlockSize }

        var totalCRC: UInt32 = 0
        while true {
            // Using `Int64` because 48 bits may not fit into `Int` on some platforms.
            let blockType = bitReader.uint64(fromBits: 48)

            let blockCRC32 = bitReader.uint32(fromBits: 32)

            if blockType == 0x314159265359 {
                let blockData = try decode(bitReader, blockSize)
                out.append(blockData)
                guard CheckSums.bzip2CRC32(blockData) == blockCRC32
                    else { throw BZip2Error.wrongCRC(out) }
                totalCRC = (totalCRC << 1) | (totalCRC >> 31)
                totalCRC ^= blockCRC32
            } else if blockType == 0x177245385090 {
                guard totalCRC == blockCRC32
                    else { throw BZip2Error.wrongCRC(out) }
                break
            } else {
                throw BZip2Error.wrongBlockType
            }
        }

        return out
    }

    private static func decode(_ bitReader: MsbBitReader, _ blockSize: BlockSize) throws -> Data {
        let isRandomized = bitReader.bit()
        guard isRandomized == 0
            else { throw BZip2Error.randomizedBlock }

        var pointer = bitReader.int(fromBits: 24)

        func computeUsed() -> [Bool] {
            let huffmanUsedMap = bitReader.int(fromBits: 16)
            var mapMask = 1 << 15
            var used = [Bool]()
            while mapMask > 0 {
                if huffmanUsedMap & mapMask > 0 {
                    let huffmanUsedBitmap = bitReader.int(fromBits: 16)
                    var bitMask = 1 << 15
                    while bitMask > 0 {
                        used.append(huffmanUsedBitmap & bitMask > 0)
                        bitMask >>= 1
                    }
                } else {
                    for _ in 0..<16 {
                        used.append(false)
                    }
                }
                mapMask >>= 1
            }
            return used
        }

        let used = computeUsed()

        let huffmanGroups = bitReader.int(fromBits: 3)
        guard huffmanGroups >= 2 && huffmanGroups <= 6
            else { throw BZip2Error.wrongHuffmanGroups }

        func computeSelectors() throws -> [Int] {
            let selectorsUsed = bitReader.int(fromBits: 15)

            var mtf = Array(0..<huffmanGroups)
            var selectorsList = [Int]()

            for _ in 0..<selectorsUsed {
                var c = 0
                while bitReader.bit() > 0 {
                    c += 1
                    guard c < huffmanGroups
                        else { throw BZip2Error.wrongSelector }
                }
                if c >= 0 {
                    let el = mtf.remove(at: c)
                    mtf.insert(el, at: 0)
                }
                selectorsList.append(mtf[0])
            }

            return selectorsList
        }

        let selectors = try computeSelectors()
        let symbolsInUse = used.filter { $0 }.count + 2

        func computeTables() throws -> [DecodingTree] {
            var tables = [DecodingTree]()
            for _ in 0..<huffmanGroups {
                var length = bitReader.int(fromBits: 5)
                var lengths = [CodeLength]()
                for i in 0..<symbolsInUse {
                    guard length >= 0 && length <= 20
                        else { throw BZip2Error.wrongHuffmanCodeLength }
                    while bitReader.bit() > 0 {
                        length -= (bitReader.bit().toInt() * 2 - 1)
                    }
                    if length > 0 {
                        lengths.append(CodeLength(symbol: i, codeLength: length))
                    }
                }
                let codes = Code.huffmanCodes(from: lengths)
                let table = DecodingTree(codes: codes.codes, maxBits: codes.maxBits, bitReader)
                tables.append(table)
            }

            return tables
        }

        let tables = try computeTables()
        var usedBytes = used.enumerated().reduce(into: [UInt8]()) {
            if $1.element {
                $0.append($1.offset.toUInt8())
            }
        }

        var selectorPointer = 0
        var decoded = 0
        var runLength = 0
        var repeatPower = 0
        var buffer: [UInt8] = []
        var currentTable: DecodingTree?

        while true {
            decoded -= 1
            if decoded <= 0 {
                decoded = 50
                if selectorPointer == selectors.count {
                    throw BZip2Error.wrongSelector
                } else if selectorPointer < selectors.count {
                    currentTable = tables[selectors[selectorPointer]]
                    selectorPointer += 1
                }
            }

            guard let symbol = currentTable?.findNextSymbol(), symbol != -1
                else { throw BZip2Error.symbolNotFound }

            if symbol == 0 || symbol == 1 { // RUNA and RUNB symbols.
                if runLength == 0 {
                    repeatPower = 1
                }
                runLength += repeatPower << symbol
                repeatPower <<= 1
                continue
            } else if runLength > 0 {
                for _ in 0..<runLength {
                    buffer.append(usedBytes[0])
                }
                runLength = 0
            }
            if symbol == symbolsInUse - 1 { // End of stream symbol.
                break
            } else { // Move to front inverse.
                let element = usedBytes.remove(at: symbol - 1)
                usedBytes.insert(element, at: 0)
                buffer.append(element)
            }
        }

        let nt = BurrowsWheeler.reverse(bytes: buffer, pointer)

        // Run Length Decoding
        var i = 0
        var out = [UInt8]()
        out.reserveCapacity(blockSize.sizeInKilobytes * 1000)
        while i < nt.count {
            if i < nt.count - 4 && nt[i] == nt[i + 1] && nt[i] == nt[i + 2] && nt[i] == nt[i + 3] {
                let runLength = nt[i + 4] + 4
                for _ in 0..<runLength {
                    out.append(nt[i])
                }
                i += 5
            } else {
                out.append(nt[i])
                i += 1
            }
        }

        return Data(out)
    }

}
