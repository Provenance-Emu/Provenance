// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

struct XZStreamHeader {

    enum CheckType: UInt8 {
        case none = 0x00
        case crc32 = 0x01
        case crc64 = 0x04
        case sha256 = 0x0A

        var size: Int {
            switch self {
            case .none:
                return 0
            case .crc32:
                return 4
            case .crc64:
                return 8
            case .sha256:
                return 32
            }
        }
    }

    let checkType: CheckType
    let flagsCRC: UInt32

    init(_ byteReader: ByteReader) throws {
        // Check magic number.
        guard byteReader.bytes(count: 6) == [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]
            else { throw XZError.wrongMagic }

        let flagsBytes = byteReader.bytes(count: 2)

        // First, we need to check for corruption in flags,
        //  so we compare CRC32 of flags to the value stored in archive.
        let flagsCRC = byteReader.uint32()
        guard CheckSums.crc32(flagsBytes) == flagsCRC
            else { throw XZError.wrongInfoCRC }
        self.flagsCRC = flagsCRC

        // If data is not corrupted, then some bits must be equal to zero.
        guard flagsBytes[0] == 0 && flagsBytes[1] & 0xF0 == 0
            else { throw XZError.wrongField }

        // Four bits of second flags byte indicate type of redundancy check.
        if let checkType = CheckType(rawValue: flagsBytes[1] & 0xF) {
            self.checkType = checkType
        } else {
            throw XZError.wrongField
        }
    }

}
