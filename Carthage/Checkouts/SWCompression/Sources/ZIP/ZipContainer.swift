// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with ZIP containers.
public class ZipContainer: Container {

    /**
     Contains user-defined extra fields. When either `ZipContainer.info(container:)` or `ZipContainer.open(container:)`
     function encounters extra field without built-in support, it uses this dictionary and tries to find a corresponding
     user-defined extra field. If an approriate custom extra field is found and successfully processed, then the result
     is stored in `ZipEntryInfo.customExtraFields`.

     To enable support of custom extra field one must add a new entry to this dictionary. The value of this entry must
     be a user-defined type which conforms to `ZipExtraField` protocol. The key must be equal to the ID of user-defined
     extra field and type's `id` property.

     - Warning: Modifying this dictionary while either `info(container:)` or `open(container:)` function is being
     executed may cause undefined behavior.
     */
    public static var customExtraFields = [UInt16: ZipExtraField.Type]()

    /**
     Processes ZIP container and returns an array of `ZipEntry` with information and data for all entries.

     - Important: The order of entries is defined by ZIP container and, particularly, by the creator of a given ZIP
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError` or any other error associated with compression type, depending on the type of the problem.
     It may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntry`.
     */
    public static func open(container data: Data) throws -> [ZipEntry] {
        let infos = try info(container: data)
        var entries = [ZipEntry]()

        for entryInfo in infos {
            if entryInfo.type == .directory {
                entries.append(ZipEntry(entryInfo, nil))
            } else {
                let entryDataResult = try ZipContainer.getEntryData(from: data, using: entryInfo)
                entries.append(ZipEntry(entryInfo, entryDataResult.data))
                guard !entryDataResult.crcError
                    else { throw ZipError.wrongCRC(entries) }
            }
        }

        return entries
    }

    private static func getEntryData(from data: Data, using info: ZipEntryInfo) throws -> (data: Data, crcError: Bool) {
        var uncompSize = info.uncompSize
        var compSize = info.compSize
        var crc32 = info.crc

        let fileData: Data
        let byteReader = ByteReader(data: data)
        byteReader.offset = info.dataOffset
        switch info.compressionMethod {
        case .copy:
            fileData = Data(bytes: byteReader.bytes(count: uncompSize.toInt()))
        case .deflate:
            let bitReader = LsbBitReader(byteReader)
            fileData = try Deflate.decompress(bitReader)
            // Sometimes `bitReader` has misaligned state after Deflate decompression,
            //  so we need to align before getting end index back.
            bitReader.align()
            byteReader.offset = bitReader.offset
        case .bzip2:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_BZ2)
                // BZip2 algorithm uses different bit numbering scheme.
                let bitReader = MsbBitReader(byteReader)
                fileData = try BZip2.decompress(bitReader)
                // Sometimes `bitReader` has misaligned state after BZip2 decompression,
                //  so we need to align before getting the end index back.
                bitReader.align()
                byteReader.offset = bitReader.offset
            #else
                throw ZipError.compressionNotSupported
            #endif
        case .lzma:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_LZMA)
                byteReader.offset += 4 // Skipping LZMA SDK version and size of properties.
                fileData = try LZMA.decompress(byteReader, LZMAProperties(byteReader), uncompSize.toInt())
            #else
                throw ZipError.compressionNotSupported
            #endif
        default:
            throw ZipError.compressionNotSupported
        }
        let realCompSize = byteReader.offset - info.dataOffset

        if info.hasDataDescriptor {
            // Now we need to parse data descriptor itself.
            // First, it might or might not have signature.
            let ddSignature = byteReader.uint32()
            if ddSignature != 0x08074b50 {
                byteReader.offset -= 4
            }
            // Now, let's update with values from data descriptor.
            crc32 = byteReader.uint32()
            if info.zip64FieldsArePresent {
                compSize = byteReader.uint64()
                uncompSize = byteReader.uint64()
            } else {
                compSize = byteReader.uint64(fromBytes: 4)
                uncompSize = byteReader.uint64(fromBytes: 4)
            }
        }

        guard compSize == realCompSize && uncompSize == fileData.count
            else { throw ZipError.wrongSize }
        let crcError = crc32 != CheckSums.crc32(fileData)

        return (fileData, crcError)
    }

    /**
     Processes ZIP container and returns an array of `ZipEntryInfo` with information about entries in this container.

     - Important: The order of entries is defined by ZIP container and, particularly, by the creator of a given ZIP
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError`, which may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntryInfo`.
     */
    public static func info(container data: Data) throws -> [ZipEntryInfo] {
        let byteReader = ByteReader(data: data)
        var entries = [ZipEntryInfo]()

        // First, we are looking for End of Central Directory record, specifically, for its signature.
        byteReader.offset = byteReader.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if byteReader.uint32() == 0x06054b50 {
                // We found it!
                break
            }
            if byteReader.offset == 0 {
                throw ZipError.notFoundCentralDirectoryEnd
            }
            byteReader.offset -= 5
        }

        // Then we are reading End of Central Directory record.
        let endOfCD = try ZipEndOfCentralDirectory(byteReader)
        let cdEntries = endOfCD.cdEntries

        // Now we are ready to read Central Directory itself.
        // But first, we should check for "Archive extra data record" and skip it if present.
        byteReader.offset = endOfCD.cdOffset.toInt()
        if byteReader.uint32() == 0x08064b50 {
            byteReader.offset += byteReader.int(fromBytes: 4)
        } else {
            byteReader.offset -= 4
        }

        for _ in 0..<cdEntries {
            let info = try ZipEntryInfo(byteReader, endOfCD.currentDiskNumber)
            entries.append(info)
            // Move to the next Central Directory entry.
            byteReader.offset = info.nextCdEntryOffset
        }

        return entries
    }

}
