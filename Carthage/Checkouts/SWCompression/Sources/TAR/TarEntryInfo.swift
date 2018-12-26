// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides access to information about an entry from the TAR container.
public struct TarEntryInfo: ContainerEntryInfo {

    enum SpecialEntryType: UInt8 {
        case longName = 76
        case longLinkName = 75
        case globalExtendedHeader = 103
        case localExtendedHeader = 120
        // Sun were the first to use extended headers. Their headers are mostly compatible with PAX ones, but differ in
        // the typeflag used ("X" instead of "x").
        case sunExtendedHeader = 88
    }

    // MARK: ContainerEntryInfo

    /**
     Entry's name.

     Depending on the particular format of the container, different container's structures are used
     to set this property, in the following preference order:
     1. Local PAX extended header "path" property.
     2. Global PAX extended header "path" property.
     3. GNU format type "L" (LongName) entry.
     4. Default TAR header.

     - Note: When new TAR container is created, if `name` cannot be encoded with ASCII or its ASCII byte-representation
     is longer than 100 bytes then a PAX extended header will be created to represent this value correctly.
     - Note: When creating new TAR container, `name` is always encoded with UTF-8 in basic TAR header.
     */
    public var name: String

    /**
     Entry's data size.

     - Note: This property cannot be directly modified. Instead it is updated automatically to be equal to its parent
     `entry.data.count`.
     - Note: When new TAR container is created, if `size` is bigger than 8589934591 then a PAX extended header will be
     created to represent this value correctly. Also, base-256 encoding will be used to encode this value in basic TAR
     header.
    */
    public internal(set) var size: Int?

    public let type: ContainerEntryType

    /**
     Entry's last access time (only available for PAX format; `nil` otherwise).

     - Note: When new TAR container is created, if `accessTime` is not `nil` then a PAX extended header will be created
     to store this property.
     */
    public var accessTime: Date?

    /**
     Entry's creation time (only available for PAX format; `nil` otherwise).

     - Note: When new TAR container is created, if `creationTime` is not `nil` then a PAX extended header will be
     created to store this property.
     */
    public var creationTime: Date?

    /**
     Entry's last modification time.

     - Note: When new TAR container is created, if `modificationTime` is bigger than 8589934591 then a PAX extended
     header will be created to represent this value correctly. Also, base-256 encoding will be used to encode this value
     in basic TAR header.
     */
    public var modificationTime: Date?

    public var permissions: Permissions?

    // MARK: TAR specific

    /// Entry's compression method. Always `.copy` for entries of TAR containers.
    public let compressionMethod = CompressionMethod.copy

    /**
     ID of entry's owner.

     - Note: When new TAR container is created, if `ownerID` is bigger than 2097151 then a PAX extended header will be
     created to represent this value correctly. Also, base-256 encoding will be used to encode this value in basic TAR
     header.
     */
    public var ownerID: Int?

    /**
     ID of the group of entry's owner.

     - Note: When new TAR container is created, if `groupID` is bigger than 2097151 then a PAX extended header will be
     created to represent this value correctly. Also, base-256 encoding will be used to encode this value in basic TAR
     header.
     */
    public var groupID: Int?

    /**
     User name of entry's owner.

     - Note: When new TAR container is created, if `ownerUserName` cannot be encoded with ASCII or its ASCII
     byte-representation is longer than 32 bytes then a PAX extended header will be created to represent this value
     correctly.
     - Note: When creating new TAR container, `ownerUserName` is always encoded with UTF-8 in ustar header.
     */
    public var ownerUserName: String?

    /**
     Name of the group of entry's owner.

     - Note: When new TAR container is created, if `ownerGroupName` cannot be encoded with ASCII or its ASCII
     byte-representation is longer than 32 bytes then a PAX extended header will be created to represent this value
     correctly.
     - Note: When creating new TAR container, `ownerGroupName` is always encoded with UTF-8 in ustar header.
     */
    public var ownerGroupName: String?

    /**
     Device major number (used when entry is either block or character special file).

     - Note: When new TAR container is created, if `deviceMajorNumber` is bigger than 2097151 then base-256 encoding
     will be used to encode this value in ustar header.
     */
    public var deviceMajorNumber: Int?

    /**
     Device minor number (used when entry is either block or character special file).

     - Note: When new TAR container is created, if `deviceMajorNumber` is bigger than 2097151 then base-256 encoding
     will be used to encode this value in ustar header.
     */
    public var deviceMinorNumber: Int?

    /**
     Name of the character set used to encode entry's data (only available for PAX format; `nil` otherwise).

     - Note: When new TAR container is created, if `charset` is not `nil` then a PAX extended header will be created to
     store this property.
     */
    public var charset: String?

    /**
     Entry's comment (only available for PAX format; `nil` otherwise).

     - Note: When new TAR container is created, if `comment` is not `nil` then a PAX extended header will be created to
     store this property.
     */
    public var comment: String?

    /**
     Path to a linked file for symbolic link entry.

     Depending on the particular format of the container, different container's structures are used
     to set this property, in the following preference order:
     1. Local PAX extended header "linkpath" property.
     2. Global PAX extended header "linkpath" property.
     3. GNU format type "K" (LongLink) entry.
     4. Default TAR header.

     - Note: When new TAR container is created, if `linkName` cannot be encoded with ASCII or its ASCII
     byte-representation is longer than 100 bytes then a PAX extended header will be created to represent this value
     correctly.
     - Note: When creating new TAR container, `linkName` is always encoded with UTF-8 in basic TAR header.
     */
    public var linkName: String

    /**
     All custom (unknown) records from global and local PAX extended headers. `nil`, if there were no headers.

     - Note: When new TAR container is created, if `unknownExtendedHeaderRecords` is not `nil` then a *local* PAX
     extended header will be created to store this property.
     */
    public var unknownExtendedHeaderRecords: [String: String]?

    var specialEntryType: SpecialEntryType?
    let format: TarContainer.Format

    let blockStartIndex: Int

    /**
     Initializes the entry's info with its name and type.

     - Note: Entry's type cannot be modified after initialization.

     - Parameter name: Entry's name.
     - Parameter type: Entry's type.
     */
    public init(name: String, type: ContainerEntryType) {
        self.name = name
        self.type = type
        self.linkName = ""
        // These properties are only used when entry is loaded from the container.
        self.format = .pax
        self.blockStartIndex = 0
    }

    init(_ byteReader: ByteReader, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        self.blockStartIndex = byteReader.offset

        // File name
        var name = byteReader.tarCString(maxLength: 100)

        // General notes for all the properties processing below:
        // 1. There might be a corresponding field in either global or local extended PAX header.
        // 2. We still need to read general TAR fields so we can't eliminate auxiliary local let-variables.
        // 3. `tarInt` returning `nil` corresponds to either field being unused and filled with NULLs or non-UTF-8
        //    string describing number which means that either this field or container in general is corrupted.
        //    Corruption of the container should be detected by checksum comparison, so we decided to ignore them here;
        //    the alternative, which was used in previous versions, is to throw an error.

        if let posixAttributes = byteReader.tarInt(maxLength: 8) {
            // Sometimes file mode field also contains unix type, so we need to filter it out.
            self.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)
        } else {
            self.permissions = nil
        }

        let ownerAccountID = byteReader.tarInt(maxLength: 8)
        self.ownerID = (local?.uid ?? global?.uid) ?? ownerAccountID

        let groupAccountID = byteReader.tarInt(maxLength: 8)
        self.groupID = (local?.gid ?? global?.gid) ?? groupAccountID

        guard let fileSize = byteReader.tarInt(maxLength: 12)
            else { throw TarError.wrongField }
        self.size = (local?.size ?? global?.size) ?? fileSize

        let mtime = byteReader.tarInt(maxLength: 12)
        if let paxMtime = local?.mtime ?? global?.mtime {
            self.modificationTime = Date(timeIntervalSince1970: paxMtime)
        } else if let mtime = mtime {
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Checksum
        guard let checksum = byteReader.tarInt(maxLength: 8)
            else { throw TarError.wrongHeaderChecksum }

        let currentIndex = byteReader.offset
        byteReader.offset = blockStartIndex
        var headerBytesForChecksum = byteReader.bytes(count: 512)
        headerBytesForChecksum.replaceSubrange(148..<156, with: Array(repeating: 0x20, count: 8))
        byteReader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, equality in one of them will pass the checksum test.
        let unsignedOurChecksum = headerBytesForChecksum.reduce(0 as UInt) { $0 + UInt(truncatingIfNeeded: $1) }
        let signedOurChecksum = headerBytesForChecksum.reduce(0 as Int) { $0 + $1.toInt() }
        guard unsignedOurChecksum == UInt(truncatingIfNeeded: checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        // File type
        let fileTypeIndicator = byteReader.byte()
        self.specialEntryType = SpecialEntryType(rawValue: fileTypeIndicator)
        self.type = ContainerEntryType(fileTypeIndicator)

        // Linked file name
        let linkName = byteReader.tarCString(maxLength: 100)

        // There are two different formats utilizing this section of TAR header: GNU format and POSIX (aka "ustar";
        // also PAX containers can also be considered POSIX). They differ in the value of magic field as well as what
        // comes after deviceMinorNumber field. While "ustar" format may contain prefix for file name, GNU format
        // uses this place for storing atime/ctime and fields related to sparse-files. In practice, these fields are
        // rarely used by GNU tar and only present if "incremental backups" options were used. Thus, GNU format TAR
        // container can often be incorrectly considered as having prefix field containing only NULLs.
        let magic = byteReader.uint64()

        var gnuAtime: Int?
        var gnuCtime: Int?

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            let uname = byteReader.tarCString(maxLength: 32)
            self.ownerUserName = (local?.uname ?? global?.uname) ?? uname

            let gname = byteReader.tarCString(maxLength: 32)
            self.ownerGroupName = (local?.gname ?? global?.gname) ?? gname

            self.deviceMajorNumber = byteReader.tarInt(maxLength: 8)
            self.deviceMinorNumber = byteReader.tarInt(maxLength: 8)

            if magic == 0x00_20_20_72_61_74_73_75 { // GNU format.
                // GNU format mostly is identical to POSIX format and in the common situations can be considered as
                // having prefix containing only NULLs. However, in the case of incremental backups produced by GNU tar
                // this part of the TAR header is used for storing a lot of different properties. For now, we are only
                // reading atime and ctime.

                gnuAtime = byteReader.tarInt(maxLength: 12)
                gnuCtime = byteReader.tarInt(maxLength: 12)
            } else {
                let prefix = byteReader.tarCString(maxLength: 155)
                if prefix != "" {
                    if prefix.last == "/" {
                        name = prefix + name
                    } else {
                        name = prefix + "/" + name
                    }
                }
            }
        } else {
            self.ownerUserName = local?.uname ?? global?.uname
            self.ownerGroupName = local?.gname ?? global?.gname
        }

        if local != nil || global != nil {
            self.format = .pax
        } else if magic == 0x00_20_20_72_61_74_73_75 || longName != nil || longLinkName != nil {
            self.format = .gnu
        } else if magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.format = .ustar
        } else {
            self.format = .prePosix
        }

        // Set `name` and `linkName` to values from PAX or GNU format if possible.
        self.name = ((local?.path ?? global?.path) ?? longName) ?? name
        self.linkName = ((local?.linkpath ?? global?.linkpath) ?? longLinkName) ?? linkName

        // Set additional properties from PAX extended headers.
        if let atime = local?.atime ?? global?.atime {
            self.accessTime = Date(timeIntervalSince1970: atime)
        } else if let gnuAtime = gnuAtime {
            self.accessTime = Date(timeIntervalSince1970: TimeInterval(gnuAtime))
        }

        if let ctime = local?.ctime ?? global?.ctime {
            self.creationTime = Date(timeIntervalSince1970: ctime)
        } else if let gnuCtime = gnuCtime {
            self.creationTime = Date(timeIntervalSince1970: TimeInterval(gnuCtime))
        }

        self.charset = local?.charset ?? global?.charset
        self.comment = local?.comment ?? global?.comment
        if let localUnknownRecords = local?.unknownRecords {
            if let globalUnknownRecords = global?.unknownRecords {
                self.unknownExtendedHeaderRecords = globalUnknownRecords.merging(localUnknownRecords) { $1 }
            } else {
                self.unknownExtendedHeaderRecords = localUnknownRecords
            }
        } else {
            self.unknownExtendedHeaderRecords = global?.unknownRecords
        }
    }

    func generateContainerData() throws -> Data {
        // It is not possible to encode non-english characters with ASCII (expectedly), so we are using UTF-8.
        // While this contradicts format specification, in case of ustar and basic TAR format our other options in
        // situation when it is not possible to encode with ASCII are:
        // - crash with fatalError, etc.
        // - throw an error.
        // - ignore the problem, and just write NULLs.
        // The last option is, obviously, is not ideal. Overall, it seems like using UTF-8 instead of ASCII is the most
        // viable option.

        var out = Data()

        try out.append(tarString: self.name, maxLength: 100)

        out.append(tarInt: self.permissions?.rawValue.toInt(), maxLength: 8)
        out.append(tarInt: self.ownerID, maxLength: 8)
        out.append(tarInt: self.groupID, maxLength: 8)
        out.append(tarInt: self.size, maxLength: 12)

        if let mtime = self.modificationTime?.timeIntervalSince1970 {
            out.append(tarInt: Int(mtime), maxLength: 12)
        } else {
            out.append(tarInt: nil, maxLength: 12)
        }

        // Checksum is calculated based on the complete header with spaces instead of checksum.
        out.append(contentsOf: Array(repeating: 0x20, count: 8))

        let fileTypeIndicator = self.specialEntryType?.rawValue ?? self.type.fileTypeIndicator
        out.append(fileTypeIndicator)

        try out.append(tarString: self.linkName, maxLength: 100)

        out.append(contentsOf: [0x75, 0x73, 0x74, 0x61, 0x72, 0x00, 0x30, 0x30]) // "ustar\000"
        // In theory, user/group name is not guaranteed to have only ASCII characters, so the same disclaimer as for
        // file name field applies here.
        try out.append(tarString: self.ownerUserName, maxLength: 32)
        try out.append(tarString: self.ownerGroupName, maxLength: 32)
        out.append(tarInt: self.deviceMajorNumber, maxLength: 8)
        out.append(tarInt: self.deviceMinorNumber, maxLength: 8)

        guard let nameData = self.name.data(using: .utf8)
            else { throw TarCreateError.utf8NonEncodable }

        if nameData.count > 100 {
            var maxPrefixLength = nameData.count
            if maxPrefixLength > 156 {
                // We can set actual maximum possible length of prefix equal to 156 and not 155, because it may
                // include trailing slash which will be removed during splitting.
                maxPrefixLength = 156
            } else if nameData[maxPrefixLength - 1] == 0x2F {
                // Skip trailing slash.
                maxPrefixLength -= 1
            }

            // Looking for the last slash in the potential prefix. -1 if not found.
            // It determines the end of the actual prefix and the beginning of the updated name field.
            // TODO: This is a workaround for runtime crash when executing `Data.prefix(upTo:).range(of:options:)`
            // on Linux with Swift 4.1. It seems like it is fixed in 4.2 and master snapshots, so we probably will be
            // able to remove it once Swift 4.2/5.0 releases.
            #if os(Linux) && !swift(>=4.2)
                var lastPrefixSlashIndex = -1
                for i in stride(from: maxPrefixLength - 1, through: 0, by: -1) {
                    if nameData[i] == 0x2f {
                        lastPrefixSlashIndex = i
                        break
                    }
                }
            #else
                let lastPrefixSlashIndex = nameData.prefix(upTo: maxPrefixLength)
                    .range(of: Data(bytes: [0x2f]), options: .backwards)?.lowerBound ?? -1
            #endif
            let updatedNameLength = nameData.count - lastPrefixSlashIndex - 1
            let prefixLength = lastPrefixSlashIndex

            if lastPrefixSlashIndex <= 0 || updatedNameLength > 100 || updatedNameLength == 0 || prefixLength > 155 {
                // Unsplittable name.
                out.append(Data(count: 155))
            } else {
                // Add prefix data to output.
                out.append(nameData.prefix(upTo: lastPrefixSlashIndex))
                // Update name field data in output.
                var newNameData = nameData.suffix(from: lastPrefixSlashIndex + 1)
                newNameData.append(Data(count: 100 - newNameData.count))
                out.replaceSubrange(0..<100, with: newNameData)
            }
        } else {
            out.append(Data(count: 155)) // Empty prefix
        }

        // Checksum calculation.
        // First, we pad header data to 512 bytes.
        out.append(Data(count: 512 - out.count))
        let checksum = out.reduce(0 as Int) { $0 + $1.toInt() }
        let checksumString = String(format: "%06o", checksum).appending("\0 ")
        out.replaceSubrange(148..<156, with: checksumString.data(using: .ascii)!)

        return out
    }

}

fileprivate extension Data {

    /// This works (hopefully) in the same way as `String.padding(toLength: length, withPad: "\0", startingAt: 0)`.
    @inline(__always)
    private func zeroPad(_ length: Int) -> Data {
        var out = length < self.count ? self.prefix(upTo: length) : self
        out.append(Data(count: length - out.count))
        return out
    }

    mutating func append(tarInt value: Int?, maxLength: Int) {
        guard var value = value else {
            // No value; fill field with NULLs.
            self.append(Data(count: maxLength))
            return
        }

        let maxOctalValue = (1 << (maxLength * 3)) - 1
        guard value > maxOctalValue || value < 0 else {
            // Normal octal encoding.
            self.append(String(value, radix: 8).data(using: .utf8)!.zeroPad(maxLength))
            return
        }

        // Base-256 encoding.
        var buffer = Array(repeating: 0 as UInt8, count: maxLength)
        for i in stride(from: maxLength - 1, to: 0, by: -1) {
            buffer[i] = UInt8(truncatingIfNeeded: value & 0xFF)
            value >>= 8
        }
        buffer[0] |= 0x80 // Highest bit indicates base-256 encoding.
        self.append(Data(bytes: buffer))
    }

    mutating func append(tarString string: String?, maxLength: Int) throws {
        guard let string = string else {
            // No value; fill field with NULLs.
            self.append(Data(count: maxLength))
            return
        }

        guard let stringData = string.data(using: .utf8)?.zeroPad(maxLength)
            else { throw TarCreateError.utf8NonEncodable }
        self.append(stringData)
    }

}
