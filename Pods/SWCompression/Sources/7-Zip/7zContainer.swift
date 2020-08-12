// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with 7-Zip containers.
public class SevenZipContainer: Container {

    static let signatureHeaderSize = 32

    /**
     Processes 7-Zip container and returns an array of `SevenZipEntry` with information and data for all entries.

     - Important: The order of entries is defined by 7-Zip container and, particularly, by the creator of a given 7-Zip
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: 7-Zip container's data.

     - Throws: `SevenZipError` or any other error associated with compression type depending on the type of the problem.
     It may indicate that either container is damaged or it might not be 7-Zip container at all.

     - Returns: Array of `SevenZipEntry`.
     */
    public static func open(container data: Data) throws -> [SevenZipEntry] {
        var entries = [SevenZipEntry]()
        guard let header = try readHeader(data),
            let files = header.fileInfo?.files
            else { return [] }

        /// Total count of non-empty files. Used to iterate over SubstreamInfo.
        var nonEmptyFileIndex = 0

        /// Index of currently opened folder in `streamInfo.coderInfo.folders`.
        var folderIndex = 0

        /// Index of currently extracted file in `headerInfo.fileInfo.files`.
        var folderFileIndex = 0

        /// Index of currently read stream.
        var streamIndex = -1

        /// Total size of unpacked data for current folder. Used for consistency check.
        var folderUnpackSize = 0

        /// Combined calculated CRC of entire folder == all files in folder.
        var folderCRC = CheckSums.crc32(Data())

        /// `ByteReader` object with unpacked stream's data.
        var unpackedStreamData = ByteReader(data: Data())

        let byteReader = ByteReader(data: data)

        for file in files {
            if file.isEmptyStream {
                let info = file.isEmptyFile && !file.isAntiFile ? SevenZipEntryInfo(file, 0) : SevenZipEntryInfo(file)
                let data = file.isEmptyFile && !file.isAntiFile ? Data() : nil
                entries.append(SevenZipEntry(info, data))
                continue
            }

            // Without `SevenZipStreamInfo` and `SevenZipPackInfo` we cannot find file data in container.
            guard let streamInfo = header.mainStreams,
                let packInfo = streamInfo.packInfo
                else { throw SevenZipError.internalStructureError }

            // SubstreamInfo is required to get files' data, and without it we can only return files' info.
            guard let substreamInfo = streamInfo.substreamInfo else {
                entries.append(SevenZipEntry(SevenZipEntryInfo(file), nil))
                continue
            }

            // Check if there is enough folders.
            guard folderIndex < streamInfo.coderInfo.numFolders
                else { throw SevenZipError.internalStructureError }

            /// Folder which contains current file.
            let folder = streamInfo.coderInfo.folders[folderIndex]

            // There may be several streams in a single folder, so we have to iterate over them, if necessary.
            // If we switched folders or completed reading of a stream we need to move to the next stream.
            if folderFileIndex == 0 || unpackedStreamData.isFinished {
                streamIndex += 1

                // First, we move to the stream's offset. We don't have any guarantees that streams will be
                // enountered in the same order, as they are placed in the container. Thus, we have to start moving
                // to stream's offset from the beginning.
                // TODO: Is this correct or the order of streams is guaranteed?
                byteReader.offset = signatureHeaderSize + packInfo.packPosition // Pack offset.
                if streamIndex != 0 {
                    for i in 0..<streamIndex {
                        byteReader.offset += packInfo.packSizes[i]
                    }
                }

                // Load the stream.
                let streamData = Data(byteReader.bytes(count: packInfo.packSizes[streamIndex]))

                // Check stream's CRC, if it's available.
                if streamIndex < packInfo.digests.count,
                    let storedStreamCRC = packInfo.digests[streamIndex] {
                    guard CheckSums.crc32(streamData) == storedStreamCRC
                        else { throw SevenZipError.wrongCRC }
                }

                // One stream can contain data for several files, so we need to decode the stream first, then split
                // it into files.
                unpackedStreamData = ByteReader(data: try folder.unpack(data: streamData))
            }

            // `SevenZipSubstreamInfo` object must contain information about file's size and may also contain
            // information about file's CRC32.

            // File's unpacked size is required to proceed.
            guard nonEmptyFileIndex < substreamInfo.unpackSizes.count
                else { throw SevenZipError.internalStructureError }
            let fileSize = substreamInfo.unpackSizes[nonEmptyFileIndex]

            // Check, if we aren't about to read too much from a stream.
            guard fileSize <= unpackedStreamData.bytesLeft
                else { throw SevenZipError.internalStructureError }
            let fileData = Data(unpackedStreamData.bytes(count: fileSize))

            let calculatedFileCRC = CheckSums.crc32(fileData)
            if nonEmptyFileIndex < substreamInfo.digests.count {
                guard calculatedFileCRC == substreamInfo.digests[nonEmptyFileIndex]
                    else { throw SevenZipError.wrongCRC }
            }

            let info = SevenZipEntryInfo(file, fileSize, calculatedFileCRC)
            let data = fileData
            entries.append(SevenZipEntry(info, data))

            // Update folder's crc and unpack size.
            folderUnpackSize += fileSize
            folderCRC = CheckSums.crc32(fileData, prevValue: folderCRC)

            folderFileIndex += 1
            nonEmptyFileIndex += 1

            if folderFileIndex >= folder.numUnpackSubstreams { // If we read all files in folder...
                // Check folder's unpacked size as well as its CRC32 (if it is available).
                guard folderUnpackSize == folder.unpackSize()
                    else { throw SevenZipError.wrongSize }
                if let storedFolderCRC = folder.crc {
                    guard folderCRC == storedFolderCRC
                        else { throw SevenZipError.wrongCRC }
                }
                // Reset folder's unpack size and CRC32.
                folderCRC = CheckSums.crc32(Data())
                folderUnpackSize = 0
                // Reset file index for the next folder.
                folderFileIndex = 0
                // Move to the next folder.
                folderIndex += 1
            }
        }

        return entries
    }

    /**
     Processes 7-Zip container and returns an array of `SevenZipEntryInfo` with information about entries in this
     container.

     - Important: The order of entries is defined by 7-Zip container and, particularly, by the creator of a given 7-Zip
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: 7-Zip container's data.

     - Throws: `SevenZipError` or any other error associated with compression type depending on the type of the problem.
     It may indicate that either container is damaged or it might not be 7-Zip container at all.

     - Returns: Array of `SevenZipEntryInfo`.
     */
    public static func info(container data: Data) throws -> [SevenZipEntryInfo] {
        var entries = [SevenZipEntryInfo]()
        guard let header = try readHeader(data),
            let files = header.fileInfo?.files
            else { return [] }

        var nonEmptyFileIndex = 0
        for file in files {
            if !file.isEmptyStream, let substreamInfo = header.mainStreams?.substreamInfo {
                let size = nonEmptyFileIndex < substreamInfo.unpackSizes.count ?
                    substreamInfo.unpackSizes[nonEmptyFileIndex] : nil
                let crc = nonEmptyFileIndex < substreamInfo.digests.count ?
                    substreamInfo.digests[nonEmptyFileIndex] : nil
                entries.append(SevenZipEntryInfo(file, size, crc))
                nonEmptyFileIndex += 1
            } else {
                let info = file.isEmptyFile ? SevenZipEntryInfo(file, 0) : SevenZipEntryInfo(file)
                entries.append(info)
            }
        }

        return entries
    }

    private static func readHeader(_ data: Data) throws -> SevenZipHeader? {
        let bitReader = MsbBitReader(data: data)

        // **SignatureHeader**

        // Check signature.
        guard bitReader.bytes(count: 6) == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
            else { throw SevenZipError.wrongSignature }

        // Check archive version.
        let majorVersion = bitReader.byte()
        let minorVersion = bitReader.byte()
        guard majorVersion == 0 && minorVersion > 0 && minorVersion <= 4
            else { throw SevenZipError.wrongFormatVersion }

        let startHeaderCRC = bitReader.uint32()

        /// - Note: Relative to SignatureHeader
        let nextHeaderOffset = bitReader.int(fromBytes: 8)
        let nextHeaderSize = bitReader.int(fromBytes: 8)
        let nextHeaderCRC = bitReader.uint32()

        bitReader.offset = 12
        guard CheckSums.crc32(bitReader.bytes(count: 20)) == startHeaderCRC
            else { throw SevenZipError.wrongCRC }

        // **Header**
        bitReader.offset += nextHeaderOffset
        let headerStartIndex = bitReader.offset
        let headerEndIndex: Int

        if bitReader.isFinished {
            return nil // In case of completely empty container.
        }

        let type = bitReader.byte()
        let header: SevenZipHeader

        if type == 0x17 {
            let packedHeaderStreamInfo = try SevenZipStreamInfo(bitReader)
            headerEndIndex = bitReader.offset
            header = try SevenZipHeader(bitReader, using: packedHeaderStreamInfo)
        } else if type == 0x01 {
            header = try SevenZipHeader(bitReader)
            headerEndIndex = bitReader.offset
        } else {
            throw SevenZipError.internalStructureError
        }

        // Check header size
        guard headerEndIndex - headerStartIndex == nextHeaderSize
            else { throw SevenZipError.wrongSize }

        // Check header CRC
        bitReader.offset = headerStartIndex
        guard CheckSums.crc32(bitReader.bytes(count: nextHeaderSize)) == nextHeaderCRC
            else { throw SevenZipError.wrongCRC }

        return header
    }

}
