// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Represents a GZip archive's header.
public struct GzipHeader {

    struct Flags: OptionSet {
        let rawValue: UInt8

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        static let ftext = Flags(rawValue: 0x01)
        static let fhcrc = Flags(rawValue: 0x02)
        static let fextra = Flags(rawValue: 0x04)
        static let fname = Flags(rawValue: 0x08)
        static let fcomment = Flags(rawValue: 0x10)
    }

    /// Compression method of archive. Always `.deflate` for GZip archives.
    public let compressionMethod: CompressionMethod

    /**
     The most recent modification time of the original file.
     If corresponding archive's field is set to 0, which means that no time was specified,
     then this property is `nil`.
     */
    public let modificationTime: Date?

    /// Type of file system on which archivation took place.
    public let osType: FileSystemType

    /// Name of the original file. If archive doesn't contain file's name, then `nil`.
    public let fileName: String?

    /// Comment stored in archive. If archive doesn't contain any comment, then `nil`.
    public let comment: String?

    /// True, if file is likely to be text file or ASCII-file.
    public let isTextFile: Bool

    /**
     Initializes the structure with the values from the first 'member' of GZip `archive`.

     - Parameter archive: Data archived with GZip.

     - Throws: `GzipError`. It may indicate that either archive is damaged or
     it might not be archived with GZip at all.
     */
    public init(archive data: Data) throws {
        let byteReader = ByteReader(data: data)
        try self.init(byteReader)
    }

    init(_ byteReader: ByteReader) throws {
        // First two bytes should be correct 'magic' bytes
        let magic = byteReader.uint16()
        guard magic == 0x8b1f else { throw GzipError.wrongMagic }
        var headerBytes: [UInt8] = [0x1f, 0x8b]

        // Third byte is a method of compression. Only type 8 (DEFLATE) compression is supported for GZip archives.
        let method = byteReader.byte()
        guard method == 8 else { throw GzipError.wrongCompressionMethod }
        headerBytes.append(method)
        self.compressionMethod = .deflate

        let rawFlags = byteReader.byte()
        guard rawFlags & 0xE0 == 0
            else { throw GzipError.wrongFlags }
        let flags = Flags(rawValue: rawFlags)
        headerBytes.append(rawFlags)

        var mtime = 0
        for i in 0..<4 {
            let byte = byteReader.byte()
            mtime |= byte.toInt() << (8 * i)
            headerBytes.append(byte)
        }
        self.modificationTime = mtime == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(mtime))

        let extraFlags = byteReader.byte()
        headerBytes.append(extraFlags)

        let rawOsType = byteReader.byte()
        self.osType = FileSystemType(rawOsType)
        headerBytes.append(rawOsType)

        self.isTextFile = flags.contains(.ftext)

        // Some archives may contain extra fields
        if flags.contains(.fextra) {
            var xlen = 0
            for i in 0..<2 {
                let byte = byteReader.byte()
                xlen |= byte.toInt() << (8 * i)
                headerBytes.append(byte)
            }
            for _ in 0..<xlen {
                headerBytes.append(byteReader.byte())
            }
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if flags.contains(.fname) {
            var fnameBytes: [UInt8] = []
            while true {
                let byte = byteReader.byte()
                headerBytes.append(byte)
                guard byte != 0 else { break }
                fnameBytes.append(byte)
            }
            self.fileName = String(data: Data(fnameBytes), encoding: .isoLatin1)
        } else {
            self.fileName = nil
        }

        // Some archives may contain comment (this part also ends with zero)
        if flags.contains(.fcomment) {
            var fcommentBytes: [UInt8] = []
            while true {
                let byte = byteReader.byte()
                headerBytes.append(byte)
                guard byte != 0 else { break }
                fcommentBytes.append(byte)
            }
            self.comment = String(data: Data(fcommentBytes), encoding: .isoLatin1)
        } else {
            self.comment = nil
        }

        // Some archives may contain 2-bytes checksum
        if flags.contains(.fhcrc) {
            // Note: it is not actual CRC-16, it is just two least significant bytes of CRC-32.
            let crc16 = byteReader.uint16()
            guard CheckSums.crc32(headerBytes) & 0xFFFF == crc16 else { throw GzipError.wrongHeaderCRC }
        }
    }

}
