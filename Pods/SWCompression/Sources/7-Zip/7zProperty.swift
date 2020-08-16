// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipProperty {

    let type: UInt8
    let size: Int
    let bytes: [UInt8]

    init(_ type: UInt8, _ size: Int, _ bytes: [UInt8]) {
        self.type = type
        self.size = size
        self.bytes = bytes
    }

    static func getProperties(_ bitReader: MsbBitReader) throws -> [SevenZipProperty] {
        var properties = [SevenZipProperty]()
        while true {
            let propertyType = bitReader.byte()
            if propertyType == 0 {
                break
            }
            let propertySize = bitReader.szMbd()
            properties.append(SevenZipProperty(propertyType, propertySize, bitReader.bytes(count: propertySize)))
        }
        return properties
    }

}
