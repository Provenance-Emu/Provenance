// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides access to information about an entry from the ZIP container.
public struct ZipEntryInfo: ContainerEntryInfo {

    // MARK: ContainerEntryInfo

    public let name: String

    public let size: Int?

    public let type: ContainerEntryType

    /**
     Entry's last access time (`nil`, if not available).

     Set from different sources in the following preference order:
     1. Extended timestamp extra field (most common on UNIX-like systems).
     2. NTFS extra field.
    */
    public let accessTime: Date?

    /**
     Entry's creation time (`nil`, if not available).

     Set from different sources in the following preference order:
     1. Extended timestamp extra field (most common on UNIX-like systems).
     2. NTFS extra field.
     */
    public let creationTime: Date?

    /**
     Entry's last modification time.

     Set from different sources in the following preference order:
     1. Extended timestamp extra field (most common on UNIX-like systems).
     2. NTFS extra field.
     3. ZIP container's own storage (in Central Directory entry).
     */
    public let modificationTime: Date?

    /**
     Entry's permissions in POSIX format.
     May have meaningless value if origin file system's attributes weren't POSIX compatible.
     */
    public let permissions: Permissions?

    // MARK: ZIP specific

    /// Entry's comment.
    public let comment: String

    /**
     Entry's external file attributes. ZIP internal property.
     May be useful when origin file system's attributes weren't POSIX compatible.
     */
    public let externalFileAttributes: UInt32

    /// Entry's attributes in DOS format.
    public let dosAttributes: DosAttributes?

    /// True, if entry is likely to be text or ASCII file.
    public let isTextFile: Bool

    /// File system type of container's origin.
    public let fileSystemType: FileSystemType

    /// Entry's compression method.
    public let compressionMethod: CompressionMethod

    /**
     ID of entry's owner.

     Set from different sources in the following preference order, if possible:
     1. Info-ZIP New Unix extra field.
     2. Info-ZIP Unix extra field.
     */
    public let ownerID: Int?

    /**
     ID of the group of entry's owner.

     Set from different sources in the following preference order, if possible:
     1. Info-ZIP New Unix extra field.
     2. Info-ZIP Unix extra field.
     */
    public let groupID: Int?

    /**
     Entry's custom extra fields from both Central Directory and Local Header.

     - Note: No particular order of extra fields is guaranteed.
     */
    public let customExtraFields: [ZipExtraField]

    /// CRC32 of entry's data.
    public let crc: UInt32

    let hasDataDescriptor: Bool
    let zip64FieldsArePresent: Bool
    let nextCdEntryOffset: Int
    let dataOffset: Int
    let compSize: UInt64
    let uncompSize: UInt64

    init(_ byteReader: ByteReader, _ currentDiskNumber: UInt32) throws {
        // Read Central Directory entry.
        let cdEntry = try ZipCentralDirectoryEntry(byteReader)

        // Move to the location of Local Header.
        byteReader.offset = cdEntry.localHeaderOffset.toInt()
        // Read Local Header.
        let localHeader = try ZipLocalHeader(byteReader)
        try localHeader.validate(with: cdEntry, currentDiskNumber)

        // If file has data descriptor, then some properties are only present in CD entry.
        self.hasDataDescriptor = localHeader.generalPurposeBitFlags & 0x08 != 0

        // Name.
        self.name = cdEntry.fileName

        // Set Modification Time.
        if let mtime = cdEntry.extendedTimestampExtraField?.mtime {
            // Extended Timestamp extra field.
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        } else if let mtime = cdEntry.ntfsExtraField?.mtime {
            // NTFS extra field.
            self.modificationTime = Date(mtime)
        } else {
            // Native ZIP modification time.
            let dosDate = cdEntry.lastModFileDate.toInt()

            let day = dosDate & 0x1F
            let month = (dosDate & 0x1E0) >> 5
            let year = 1980 + ((dosDate & 0xFE00) >> 9)

            let dosTime = cdEntry.lastModFileTime.toInt()

            let seconds = 2 * (dosTime & 0x1F)
            let minutes = (dosTime & 0x7E0) >> 5
            let hours = (dosTime & 0xF800) >> 11

            self.modificationTime = DateComponents(calendar: Calendar.current, timeZone: TimeZone.current,
                                                   year: year, month: month, day: day,
                                                   hour: hours, minute: minutes, second: seconds).date
        }

        // Set Creation Time.
        if let ctime = localHeader.extendedTimestampExtraField?.ctime {
            // Extended Timestamp extra field.
            self.creationTime = Date(timeIntervalSince1970: TimeInterval(ctime))
        } else if let ctime = cdEntry.ntfsExtraField?.ctime {
            // NTFS extra field.
            self.creationTime = Date(ctime)
        } else {
            self.creationTime = nil
        }

        // Set Creation Time.
        if let atime = localHeader.extendedTimestampExtraField?.atime {
            // Extended Timestamp extra field.
            self.accessTime = Date(timeIntervalSince1970: TimeInterval(atime))
        } else if let atime = cdEntry.ntfsExtraField?.atime {
            // NTFS extra field.
            self.accessTime = Date(atime)
        } else {
            self.accessTime = nil
        }

        // Size
        self.size = (hasDataDescriptor ? cdEntry.uncompSize : localHeader.uncompSize).toInt()

        // External file attributes.
        self.externalFileAttributes = cdEntry.externalFileAttributes
        self.permissions = Permissions(rawValue: (0x0FFF0000 & cdEntry.externalFileAttributes) >> 16)
        self.dosAttributes = DosAttributes(rawValue: 0xFF & cdEntry.externalFileAttributes)

        // Set entry type.
        if let unixType = ContainerEntryType((0xF0000000 & cdEntry.externalFileAttributes) >> 16) {
            self.type = unixType
        } else if let dosAttributes = self.dosAttributes {
            if dosAttributes.contains(.directory) {
                self.type = .directory
            } else {
                self.type = .regular
            }
        } else if size == 0 && cdEntry.fileName.last == "/" {
            self.type = .directory
        } else {
            self.type = .regular
        }

        self.comment = cdEntry.fileComment
        self.isTextFile = cdEntry.internalFileAttributes & 0x1 != 0
        self.fileSystemType = FileSystemType(cdEntry.versionMadeBy)
        self.compressionMethod = CompressionMethod(localHeader.compressionMethod)
        self.ownerID = localHeader.infoZipNewUnixExtraField?.uid ?? localHeader.infoZipUnixExtraField?.uid
        self.groupID = localHeader.infoZipNewUnixExtraField?.gid ?? localHeader.infoZipUnixExtraField?.gid
        self.crc = hasDataDescriptor ? cdEntry.crc32 : localHeader.crc32

        // Custom extra fields.
        var customExtraFields = cdEntry.customExtraFields
        customExtraFields.append(contentsOf: localHeader.customExtraFields)
        self.customExtraFields = customExtraFields

        // Save some properties from CD entry and Local Header.
        self.zip64FieldsArePresent = localHeader.zip64FieldsArePresent
        self.nextCdEntryOffset = cdEntry.nextEntryOffset
        self.dataOffset = localHeader.dataOffset
        self.compSize = hasDataDescriptor ? cdEntry.compSize : localHeader.compSize
        self.uncompSize = hasDataDescriptor ? cdEntry.uncompSize : localHeader.uncompSize
    }

}
