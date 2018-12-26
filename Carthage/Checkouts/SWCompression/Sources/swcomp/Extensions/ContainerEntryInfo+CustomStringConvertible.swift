// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension ContainerEntryInfo where Self: CustomStringConvertible {

    public var description: String {
        var output = "Name: \(self.name)\n"

        switch self.type {
        case .blockSpecial:
            output += "Type: block device file\n"
        case .characterSpecial:
            output += "Type: character device file\n"
        case .contiguous:
            output += "Type: contiguous file\n"
        case .directory:
            output += "Type: directory\n"
        case .fifo:
            output += "Type: fifo file\n"
        case .hardLink:
            output += "Type: hard link\n"
        case .regular:
            output += "Type: regular file\n"
        case .socket:
            output += "Type: socket\n"
        case .symbolicLink:
            output += "Type: symbolic link\n"
        case .unknown:
            output += "Type: unknown\n"
        }

        if let tarEntry = self as? TarEntryInfo {
            if tarEntry.type == .symbolicLink {
                output += "Linked path: \(tarEntry.linkName)\n"
            }
            if let ownerID = tarEntry.ownerID {
                output += "Uid: \(ownerID)\n"
            }
            if let groupID = tarEntry.groupID {
                output += "Gid: \(groupID)\n"
            }
            if let ownerUserName = tarEntry.ownerUserName {
                output += "Uname: \(ownerUserName)\n"
            }
            if let ownerGroupName = tarEntry.ownerGroupName {
                output += "Gname: \(ownerGroupName)\n"
            }
            if let comment = tarEntry.comment {
                output += "Comment: \(comment)\n"
            }
            if let unknownPaxRecords = tarEntry.unknownExtendedHeaderRecords, unknownPaxRecords.count > 0 {
                output += "Unknown PAX (extended header) records:\n"
                for entry in unknownPaxRecords {
                    output += "  \(entry.key): \(entry.value)\n"
                }
            }
        }

        if let zipEntry = self as? ZipEntryInfo {
            output += "Comment: \(zipEntry.comment)\n"
            output += String(format: "External File Attributes: 0x%08X\n", zipEntry.externalFileAttributes)
            output += "Is text file: \(zipEntry.isTextFile)\n"
            output += "File system type: \(zipEntry.fileSystemType)\n"
            output += "Compression method: \(zipEntry.compressionMethod)\n"
            if let ownerID = zipEntry.ownerID {
                output += "Uid: \(ownerID)\n"
            }
            if let groupID = zipEntry.groupID {
                output += "Gid: \(groupID)\n"
            }
            output += String(format: "CRC32: 0x%08X\n", zipEntry.crc)
        }

        if let sevenZipEntry = self as? SevenZipEntryInfo {
            if let winAttrs = sevenZipEntry.winAttributes {
                output += String(format: "Win attributes: 0x%08X\n", winAttrs)
            }
            if let crc = sevenZipEntry.crc {
                output += String(format: "CRC32: 0x%08X\n", crc)
            }
            output += "Has stream: \(sevenZipEntry.hasStream)\n"
            output += "Is empty: \(sevenZipEntry.isEmpty)\n"
            output += "Is anti-file: \(sevenZipEntry.isAnti)\n"
        }

        if let size = self.size {
            output += "Size: \(size) bytes\n"
        }

        if let mtime = self.modificationTime {
            output += "Mtime: \(mtime)\n"
        }

        if let atime = self.accessTime {
            output += "Atime: \(atime)\n"
        }

        if let ctime = self.creationTime {
            output += "Ctime: \(ctime)\n"
        }

        if let permissions = self.permissions?.rawValue {
            output += String(format: "Permissions: %o", permissions)
        }

        return output
    }

}

extension TarEntryInfo: CustomStringConvertible { }

extension ZipEntryInfo: CustomStringConvertible { }

extension SevenZipEntryInfo: CustomStringConvertible { }
