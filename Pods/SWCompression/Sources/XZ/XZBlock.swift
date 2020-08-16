// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

struct XZBlock {

    let data: Data
    let unpaddedSize: Int

    var uncompressedSize: Int {
        return data.count
    }

    init(_ blockHeaderSize: UInt8, _ byteReader: ByteReader, _ checkSize: Int) throws {
        let blockHeaderStartIndex = byteReader.offset - 1
        let realBlockHeaderSize = (blockHeaderSize.toInt() + 1) * 4

        let blockFlags = byteReader.byte()
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let filtersCount = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.wrongField }

        /// Should match size of compressed data.
        let compressedSize = blockFlags & 0x40 != 0 ? try byteReader.multiByteDecode() : -1

        /// Should match the size of data after decompression.
        let uncompressedSize = blockFlags & 0x80 != 0 ? try byteReader.multiByteDecode() : -1

        var filters: [(ByteReader) throws -> Data] = []
        for _ in 0..<filtersCount {
            let filterID = try byteReader.multiByteDecode()
            guard UInt64(filterID) < 0x4000000000000000
                else { throw XZError.wrongFilterID }
            // Only LZMA2 filter is supported.
            switch filterID {
            case 0x21:
                // First, we need to check if size of LZMA2 filter's properties is equal to 1 as expected.
                let propertiesSize = try byteReader.multiByteDecode()
                guard propertiesSize == 1
                    else { throw LZMA2Error.wrongDictionarySize }
                /// Filter property for LZMA2 is a dictionary size.
                let filterPropeties = byteReader.byte()
                filters.append { try LZMA2.decompress($0, filterPropeties) }
            case 0x03:
                // First, we need to check if size of Delta filter's properties is equal to 1 as expected.
                let propertiesSize = try byteReader.multiByteDecode()
                guard propertiesSize == 1
                    else { throw XZError.wrongField }
                let distance = (byteReader.byte() &+ 1).toInt()
                filters.append { DeltaFilter.decode($0, distance) }
            default:
                throw XZError.wrongFilterID
            }
        }

        // We need to take into account 4 bytes for CRC32 so thats why "-4".
        while byteReader.offset - blockHeaderStartIndex < realBlockHeaderSize - 4 {
            let byte = byteReader.byte()
            guard byte == 0x00
                else { throw XZError.wrongPadding }
        }

        let blockHeaderCRC = byteReader.uint32()
        byteReader.offset = blockHeaderStartIndex
        guard CheckSums.crc32(byteReader.bytes(count: realBlockHeaderSize - 4)) == blockHeaderCRC
            else { throw XZError.wrongInfoCRC }
        byteReader.offset += 4

        let compressedDataStart = byteReader.offset
        let out = try filters.reversed().reduce(byteReader) { try ByteReader(data: $1($0)) }

        guard compressedSize < 0 || compressedSize == byteReader.offset - compressedDataStart,
            uncompressedSize < 0 || uncompressedSize == out.data.count
            else { throw XZError.wrongDataSize }

        let unpaddedSize = byteReader.offset - blockHeaderStartIndex

        if unpaddedSize % 4 != 0 {
            let paddingSize = 4 - unpaddedSize % 4
            for _ in 0..<paddingSize {
                let byte = byteReader.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
            }
        }

        self.data = out.data
        self.unpaddedSize = unpaddedSize + checkSize
    }

}
