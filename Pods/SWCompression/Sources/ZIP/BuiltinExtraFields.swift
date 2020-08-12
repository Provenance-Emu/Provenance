// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

struct ExtendedTimestampExtraField: ZipExtraField {

    static let id: UInt16 = 0x5455

    let size: Int
    let location: ZipExtraFieldLocation

    var atime: UInt32?
    var ctime: UInt32?
    var mtime: UInt32?

    init(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        let endOffset = byteReader.offset + size
        self.size = size
        self.location = location
        switch location {
        case .centralDirectory:
            let flags = byteReader.byte()
            if flags & 0x01 != 0 {
                self.mtime = byteReader.uint32()
            }
        case .localHeader:
            let flags = byteReader.byte()
            if flags & 0x01 != 0 {
                self.mtime = byteReader.uint32()
            }
            if flags & 0x02 != 0 {
                self.atime = byteReader.uint32()
            }
            if flags & 0x04 != 0 {
                self.ctime = byteReader.uint32()
            }
        }
        // This is a workaround for non well-formed extra field present in Central Directory of ZIP files created
        // by Finder in some versions of macOS.
        byteReader.offset = endOffset
    }

}

struct NtfsExtraField: ZipExtraField {

    static let id: UInt16 = 0x000A

    let size: Int
    let location: ZipExtraFieldLocation

    let atime: UInt64
    let ctime: UInt64
    let mtime: UInt64

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        byteReader.offset += 4 // Skip reserved bytes
        let tag = byteReader.uint16() // This attribute's tag
        byteReader.offset += 2 // Skip size of this attribute
        guard tag == 0x0001
            else { return nil }
        self.mtime = byteReader.uint64()
        self.atime = byteReader.uint64()
        self.ctime = byteReader.uint64()
    }

}

struct InfoZipUnixExtraField: ZipExtraField {

    static let id: UInt16 = 0x7855

    let size: Int
    let location: ZipExtraFieldLocation

    let uid: Int
    let gid: Int

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        switch location {
        case .centralDirectory:
            return nil
        case .localHeader:
            self.uid = byteReader.int(fromBytes: 2)
            self.gid = byteReader.int(fromBytes: 2)
        }
    }

}

struct InfoZipNewUnixExtraField: ZipExtraField {

    static let id: UInt16 = 0x7875

    let size: Int
    let location: ZipExtraFieldLocation

    var uid: Int?
    var gid: Int?

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        guard byteReader.byte() == 1 // Version must be 1
            else { return nil }

        let uidSize = byteReader.byte().toInt()
        if uidSize > 8 {
            byteReader.offset += uidSize
        } else {
            self.uid = byteReader.int(fromBytes: uidSize)
        }

        let gidSize = byteReader.byte().toInt()
        if gidSize > 8 {
            byteReader.offset += gidSize
        } else {
            self.gid = byteReader.int(fromBytes: gidSize)
        }
    }

}
