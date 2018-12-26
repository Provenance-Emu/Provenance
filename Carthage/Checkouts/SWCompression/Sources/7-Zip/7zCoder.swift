// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipCoder {

    let idSize: Int
    let isComplex: Bool
    let hasAttributes: Bool

    let id: [UInt8]
    let compressionMethod: CompressionMethod
    let isEncryptionMethod: Bool

    let numInStreams: Int
    let numOutStreams: Int

    var propertiesSize: Int?
    var properties: [UInt8]?

    init(_ bitReader: MsbBitReader) throws {
        let flags = bitReader.byte()
        guard flags & 0xC0 == 0
            else { throw SevenZipError.internalStructureError }
        idSize = (flags & 0x0F).toInt()
        isComplex = flags & 0x10 != 0
        hasAttributes = flags & 0x20 != 0

        id = bitReader.bytes(count: idSize)
        compressionMethod = CompressionMethod(id)
        isEncryptionMethod = id[0] == 0x06

        numInStreams = isComplex ? bitReader.szMbd() : 1
        numOutStreams = isComplex ? bitReader.szMbd() : 1

        if hasAttributes {
            propertiesSize = bitReader.szMbd()
            properties = bitReader.bytes(count: propertiesSize!)
        }
    }

}
