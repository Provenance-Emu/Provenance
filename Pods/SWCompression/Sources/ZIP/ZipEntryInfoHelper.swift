// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/**
 The purpose of this struct is to accompany `ZipEntryInfo` instances while processing a `ZipContainer` and to store
 information which is necessary for reading entry's data later.
 */
struct ZipEntryInfoHelper {

    let entryInfo: ZipEntryInfo

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

        self.entryInfo = ZipEntryInfo(byteReader, cdEntry, localHeader, hasDataDescriptor)

        // Save some properties from CD entry and Local Header.
        self.zip64FieldsArePresent = localHeader.zip64FieldsArePresent
        self.nextCdEntryOffset = cdEntry.nextEntryOffset
        self.dataOffset = localHeader.dataOffset
        self.compSize = hasDataDescriptor ? cdEntry.compSize : localHeader.compSize
        self.uncompSize = hasDataDescriptor ? cdEntry.uncompSize : localHeader.uncompSize
    }

}
