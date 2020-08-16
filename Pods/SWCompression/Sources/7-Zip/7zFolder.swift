// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipFolder {

    struct BindPair {

        let inIndex: Int
        let outIndex: Int

        init(_ bitReader: MsbBitReader) throws {
            inIndex = bitReader.szMbd()
            outIndex = bitReader.szMbd()
        }

    }

    let numCoders: Int
    private(set) var coders = [SevenZipCoder]()

    let numBindPairs: Int
    private(set) var bindPairs = [BindPair]()

    let numPackedStreams: Int
    private(set) var packedStreams = [Int]()

    private(set) var totalOutputStreams = 0
    private(set) var totalInputStreams = 0

    // These properties are stored in CoderInfo.
    var crc: UInt32?
    var unpackSizes = [Int]()

    // This property is stored in SubstreamInfo.
    var numUnpackSubstreams = 1

    lazy var orderedCompressionMethods: [CompressionMethod] = {
        self.orderedCoders().map { $0.compressionMethod }
    }()

    init(_ bitReader: MsbBitReader) throws {
        numCoders = bitReader.szMbd()
        for _ in 0..<numCoders {
            let coder = try SevenZipCoder(bitReader)
            coders.append(coder)
            totalOutputStreams += coder.numOutStreams
            totalInputStreams += coder.numInStreams
        }

        guard totalOutputStreams != 0
            else { throw SevenZipError.internalStructureError }

        numBindPairs = totalOutputStreams - 1
        if numBindPairs > 0 {
            for _ in 0..<numBindPairs {
                bindPairs.append(try BindPair(bitReader))
            }
        }

        guard totalInputStreams >= numBindPairs
            else { throw SevenZipError.internalStructureError }

        numPackedStreams = totalInputStreams - numBindPairs
        if numPackedStreams == 1 {
            var i = 0
            while i < totalInputStreams {
                if self.bindPairForInStream(i) < 0 {
                    break
                }
                i += 1
            }
            if i == totalInputStreams {
                throw SevenZipError.internalStructureError
            }
            packedStreams.append(i)
        } else {
            for _ in 0..<numPackedStreams {
                packedStreams.append(bitReader.szMbd())
            }
        }
    }

    func orderedCoders() -> [SevenZipCoder] {
        var result = [SevenZipCoder]()
        var current = 0
        while current != -1 {
            result.append(coders[current])
            let pair = bindPairForOutStream(current)
            current = pair != -1 ? bindPairs[pair].inIndex : -1
        }
        return result
    }

    func bindPairForInStream(_ index: Int) -> Int {
        for i in 0..<bindPairs.count {
            if bindPairs[i].inIndex == index {
                return i
            }
        }
        return -1
    }

    func bindPairForOutStream(_ index: Int) -> Int {
        for i in 0..<bindPairs.count {
            if bindPairs[i].outIndex == index {
                return i
            }
        }
        return -1
    }

    func unpackSize() -> Int {
        if totalOutputStreams == 0 {
            return 0
        }
        for i in stride(from: totalOutputStreams - 1, through: 0, by: -1) {
            if bindPairForOutStream(i) < 0 {
                return unpackSizes[i]
            }
        }
        return 0
    }

    func unpackSize(for coder: SevenZipCoder) -> Int {
        for i in 0..<coders.count {
            if coders[i] == coder {
                return unpackSizes[i]
            }
        }
        return 0
    }

    func unpack(data: Data) throws -> Data {
        var decodedData = data
        for coder in self.orderedCoders() {
            guard coder.numInStreams == 1 || coder.numOutStreams == 1
                else { throw SevenZipError.multiStreamNotSupported }

            let unpackSize = self.unpackSize(for: coder)

            switch coder.compressionMethod {
            case .copy:
                continue
            case .deflate:
                #if (!SWCOMPRESSION_POD_SEVENZIP) || (SWCOMPRESSION_POD_SEVENZIP && SWCOMPRESSION_POD_DEFLATE)
                    decodedData = try Deflate.decompress(data: decodedData)
                #else
                    throw SevenZipError.compressionNotSupported
                #endif
            case .bzip2:
                #if (!SWCOMPRESSION_POD_SEVENZIP) || (SWCOMPRESSION_POD_SEVENZIP && SWCOMPRESSION_POD_BZ2)
                    decodedData = try BZip2.decompress(data: decodedData)
                #else
                    throw SevenZipError.compressionNotSupported
                #endif
            case .lzma2:
                // Dictionary size is stored in coder's properties.
                guard let properties = coder.properties,
                    properties.count == 1
                    else { throw LZMA2Error.wrongDictionarySize }

                decodedData = try LZMA2.decompress(ByteReader(data: decodedData), properties[0])
            case .lzma:
                // Both properties' byte (lp, lc, pb) and dictionary size are stored in coder's properties.
                guard let properties = coder.properties,
                    properties.count == 5
                    else { throw LZMAError.wrongProperties }

                var dictionarySize = 0
                for i in 1..<4 {
                    dictionarySize |= properties[i].toInt() << (8 * (i - 1))
                }
                let lzmaProperties = try LZMAProperties(lzmaByte: properties[0], dictionarySize)
                decodedData = try LZMA.decompress(data: decodedData,
                                                  properties: lzmaProperties,
                                                  uncompressedSize: unpackSize)
            default:
                if coder.id == [0x03] {
                    guard let properties = coder.properties,
                        properties.count == 1
                        else { throw SevenZipError.internalStructureError }

                    decodedData = DeltaFilter.decode(ByteReader(data: decodedData), (properties[0] &+ 1).toInt())
                } else if coder.isEncryptionMethod {
                    throw SevenZipError.encryptionNotSupported
                } else {
                    throw SevenZipError.compressionNotSupported
                }
            }

            guard decodedData.count == unpackSize
                else { throw SevenZipError.wrongSize }
        }
        return decodedData
    }

}
