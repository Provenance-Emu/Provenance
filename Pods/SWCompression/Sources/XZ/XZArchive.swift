// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides unarchive function for XZ archives.
public class XZArchive: Archive {

    /**
     Unarchives XZ archive. Archives with multiple streams are supported,
     but uncompressed data from each stream will be combined into single `Data` object.

     If an error happens during LZMA2 decompression, then `LZMAError` or `LZMA2Error` will be thrown.

     - Parameter archive: Data archived using XZ format.

     - Throws: `LZMAError`, `LZMA2Error` or `XZError` depending on the type of the problem.
     Particularly, if filters other than LZMA2 are used in archive, then `XZError.wrongFilterID` will be thrown,
     but it may also indicate that either the archive is damaged or
     it might not be compressed with XZ or LZMA(2) at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archive data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bytes.
        let byteReader = ByteReader(data: data)

        // Note: We don't check footer's magic bytes at the beginning,
        //  because it is impossible to determine the end of each stream in multi-stream archives
        //  without fully processing them, and checking last stream's footer doesn't
        //  guarantee correctness of other streams.

        var result = Data()
        while !byteReader.isFinished {
            let streamResult = try processStream(byteReader)
            result.append(streamResult.data)
            guard !streamResult.checkError
                else { throw XZError.wrongCheck([result]) }

            try processPadding(byteReader)
        }

        return result
    }

    /**
     Unarchives XZ archive. Archives with multiple streams are supported,
     and uncompressed data from each stream will be stored in a separate element in the array

     If data passed is not actually XZ archive, `XZError` will be thrown.
     Particularly, if filters other than LZMA2 are used in archive, then `XZError.wrongFilterID` will be thrown.

     If an error happens during LZMA2 decompression, then `LZMAError` or `LZMA2Error` will be thrown.

     - Parameter archive: Data archived using XZ format.

     - Throws: `LZMAError`, `LZMA2Error` or `XZError` depending on the type of the problem.
     It may indicate that either the archive is damaged or it might not be compressed with XZ or LZMA(2) at all.

     - Returns: Array of unarchived data from every stream in archive.
     */
    public static func splitUnarchive(archive data: Data) throws -> [Data] {
        // Same code as in `unarchive(archive:)` but with different type of `result`.
        let byteReader = ByteReader(data: data)

        var result = [Data]()
        while !byteReader.isFinished {
            let streamResult = try processStream(byteReader)
            result.append(streamResult.data)
            guard !streamResult.checkError
                else { throw XZError.wrongCheck(result) }

            try processPadding(byteReader)
        }

        return result
    }

    private static func processStream(_ byteReader: ByteReader) throws -> (data: Data, checkError: Bool) {
        var out = Data()

        let streamHeader = try XZStreamHeader(byteReader)

        // BLOCKS AND INDEX
        var blockInfos: [(unpaddedSize: Int, uncompSize: Int)] = []
        var indexSize = -1
        while true {
            let blockHeaderSize = byteReader.byte()
            if blockHeaderSize == 0 { /// Zero value of blockHeaderSize means that we've encountered INDEX.
                indexSize = try processIndex(blockInfos, byteReader)
                break
            } else {
                let block = try XZBlock(blockHeaderSize, byteReader, streamHeader.checkType.size)
                out.append(block.data)
                switch streamHeader.checkType {
                case .none:
                    break
                case .crc32:
                    let check = byteReader.uint32()
                    guard CheckSums.crc32(block.data) == check
                        else { return (out, true) }
                case .crc64:
                    let check = byteReader.uint64()
                    guard CheckSums.crc64(block.data) == check
                        else { return (out, true) }
                case .sha256:
                    let check = byteReader.bytes(count: 32)
                    guard Sha256.hash(data: block.data) == check
                        else { return (out, true) }
                }
                blockInfos.append((block.unpaddedSize, block.uncompressedSize))
            }
        }

        // STREAM FOOTER
        try processFooter(streamHeader, indexSize, byteReader)

        return (out, false)
    }

    private static func processIndex(_ blockInfos: [(unpaddedSize: Int, uncompSize: Int)],
                                     _ byteReader: ByteReader) throws -> Int {
        let indexStartIndex = byteReader.offset - 1
        let recordsCount = try byteReader.multiByteDecode()
        guard recordsCount == blockInfos.count
            else { throw XZError.wrongField }

        for blockInfo in blockInfos {
            let unpaddedSize = try byteReader.multiByteDecode()
            guard unpaddedSize == blockInfo.unpaddedSize
                else { throw XZError.wrongField }

            let uncompSize = try byteReader.multiByteDecode()
            guard uncompSize == blockInfo.uncompSize
                else { throw XZError.wrongDataSize }
        }

        var indexSize = byteReader.offset - indexStartIndex
        if indexSize % 4 != 0 {
            let paddingSize = 4 - indexSize % 4
            for _ in 0..<paddingSize {
                let byte = byteReader.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
                indexSize += 1
            }
        }

        let indexCRC = byteReader.uint32()
        byteReader.offset = indexStartIndex
        guard CheckSums.crc32(byteReader.bytes(count: indexSize)) == indexCRC
            else { throw XZError.wrongInfoCRC }
        byteReader.offset += 4

        return indexSize + 4
    }

    private static func processFooter(_ streamHeader: XZStreamHeader, _ indexSize: Int,
                                      _ byteReader: ByteReader) throws {
        let footerCRC = byteReader.uint32()
        /// Indicates the size of Index field. Should match its real size.
        let backwardSize = (byteReader.int(fromBytes: 4) + 1) * 4
        let streamFooterFlags = byteReader.int(fromBytes: 2)

        byteReader.offset -= 6
        guard CheckSums.crc32(byteReader.bytes(count: 6)) == footerCRC
            else { throw XZError.wrongInfoCRC }

        guard backwardSize == indexSize
            else { throw XZError.wrongField }

        // Flags in the footer should be the same as in the header.
        guard streamFooterFlags & 0xFF == 0 &&
            (streamFooterFlags & 0xF00) >> 8 == streamHeader.checkType.rawValue &&
            streamFooterFlags & 0xF000 == 0
            else { throw XZError.wrongField }

        // Check footer's magic number
        guard byteReader.bytes(count: 2) == [0x59, 0x5A]
            else { throw XZError.wrongMagic }
    }

    /// Returns `true` if end of archive is reached, `false` otherwise.
    private static func processPadding(_ byteReader: ByteReader) throws {
        guard !byteReader.isFinished
            else { return }

        var paddingBytes = 0
        while true {
            let byte = byteReader.byte()
            if byte != 0 {
                if paddingBytes % 4 != 0 {
                    throw XZError.wrongPadding
                } else {
                    break
                }
            }
            if byteReader.isFinished {
                if byte != 0 || paddingBytes % 4 != 3 {
                    throw XZError.wrongPadding
                } else {
                    return
                }
            }
            paddingBytes += 1
        }
        byteReader.offset -= 1
    }

}
