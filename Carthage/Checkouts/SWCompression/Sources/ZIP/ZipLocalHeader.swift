// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

struct ZipLocalHeader {

    let versionNeeded: UInt16
    let generalPurposeBitFlags: UInt16
    let compressionMethod: UInt16
    let lastModFileTime: UInt16
    let lastModFileDate: UInt16

    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    private(set) var zip64FieldsArePresent: Bool = false

    let fileName: String

    /// 0x5455 extra field.
    private(set) var extendedTimestampExtraField: ExtendedTimestampExtraField?

    /// 0x000a extra field.
    private(set) var ntfsExtraField: NtfsExtraField?

    /// 0x7855 extra field.
    private(set) var infoZipUnixExtraField: InfoZipUnixExtraField?

    /// 0x7875 extra field.
    private(set) var infoZipNewUnixExtraField: InfoZipNewUnixExtraField?

    let customExtraFields: [ZipExtraField]

    let dataOffset: Int

    init(_ byteReader: ByteReader) throws {
        // Check signature.
        guard byteReader.uint32() == 0x04034b50
            else { throw ZipError.wrongSignature }

        self.versionNeeded = byteReader.uint16()

        self.generalPurposeBitFlags = byteReader.uint16()
        let useUtf8 = generalPurposeBitFlags & 0x800 != 0

        self.compressionMethod = byteReader.uint16()

        self.lastModFileTime = byteReader.uint16()
        self.lastModFileDate = byteReader.uint16()

        self.crc32 = byteReader.uint32()

        self.compSize = byteReader.uint64(fromBytes: 4)
        self.uncompSize = byteReader.uint64(fromBytes: 4)

        let fileNameLength = byteReader.int(fromBytes: 2)
        let extraFieldLength = byteReader.int(fromBytes: 2)

        guard let fileName = byteReader.zipString(fileNameLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileName = fileName

        let extraFieldStart = byteReader.offset
        var customExtraFields = [ZipExtraField]()
        while byteReader.offset - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            let headerID = byteReader.uint16()
            let size = byteReader.int(fromBytes: 2)
            switch headerID {
            case 0x0001: // Zip64
                // Zip64 extra field is a special case, because it requires knowledge about local header fields,
                // in particular, uncompressed and compressed sizes.
                // In local header both uncompressed size and compressed size fields are required.
                self.uncompSize = byteReader.uint64()
                self.compSize = byteReader.uint64()
                self.zip64FieldsArePresent = true
            case 0x5455: // Extended Timestamp
                self.extendedTimestampExtraField = ExtendedTimestampExtraField(byteReader, size, location: .localHeader)
            case 0x000a: // NTFS Extra Fields
                self.ntfsExtraField = NtfsExtraField(byteReader, size, location: .localHeader)
            case 0x7855: // Info-ZIP Unix Extra Field
                self.infoZipUnixExtraField = InfoZipUnixExtraField(byteReader, size, location: .localHeader)
            case 0x7875: // Info-ZIP New Unix Extra Field
                self.infoZipNewUnixExtraField = InfoZipNewUnixExtraField(byteReader, size, location: .localHeader)
            default:
                let customFieldOffset = byteReader.offset
                if let customExtraFieldType = ZipContainer.customExtraFields[headerID],
                    customExtraFieldType.id == headerID,
                    let customExtraField = customExtraFieldType.init(byteReader, size, location: .localHeader),
                    customExtraField.id == headerID {
                    precondition(customExtraField.location == .localHeader,
                                 "Custom field in Local Header with ID=\(headerID) of type=\(customExtraFieldType)"
                                    + " changed location.")
                    precondition(customExtraField.size == size,
                                 "Custom field in Local Header with ID=\(headerID) of type=\(customExtraFieldType)"
                                    + " changed size.")
                    guard byteReader.offset == customFieldOffset + size
                        else { fatalError("Custom field in Local Header with ID=\(headerID) of" +
                            "type=\(customExtraFieldType) failed to read exactly \(size) bytes.") }
                    customExtraFields.append(customExtraField)
                } else {
                    byteReader.offset = customFieldOffset + size
                }
            }
        }
        self.customExtraFields = customExtraFields

        self.dataOffset = byteReader.offset
    }

    func validate(with cdEntry: ZipCentralDirectoryEntry, _ currentDiskNumber: UInt32) throws {
        // Check Local Header for unsupported features.
        guard self.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard self.generalPurposeBitFlags & 0x2000 == 0 &&
            self.generalPurposeBitFlags & 0x40 == 0 &&
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }

        // Check Central Directory record for unsupported features.
        guard cdEntry.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard cdEntry.diskNumberStart == currentDiskNumber
            else { throw ZipError.multiVolumesNotSupported }

        // Check if Local Header is consistent with Central Directory record.
        guard self.generalPurposeBitFlags == cdEntry.generalPurposeBitFlags &&
            self.compressionMethod == cdEntry.compressionMethod &&
            self.lastModFileTime == cdEntry.lastModFileTime &&
            self.lastModFileDate == cdEntry.lastModFileDate
            else { throw ZipError.wrongLocalHeader }
    }

}
