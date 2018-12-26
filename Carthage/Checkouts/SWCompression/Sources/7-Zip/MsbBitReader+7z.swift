// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension MsbBitReader {

    /// Abbreviation for "sevenZipMultiByteDecode".
    func szMbd() -> Int {
        self.align()
        let firstByte = self.byte().toInt()
        var mask = 0x80
        var value = 0
        for i in 0..<8 {
            if firstByte & mask == 0 {
                value |= ((firstByte & (mask &- 1)) << (8 * i))
                break
            }
            value |= self.byte().toInt() << (8 * i)
            mask >>= 1
        }
        return value
    }

    func defBits(count: Int) -> [UInt8] {
        self.align()
        let allDefined = self.byte()
        let definedBits: [UInt8]
        if allDefined == 0 {
            definedBits = self.bits(count: count)
        } else {
            definedBits = Array(repeating: 1, count: count)
        }
        return definedBits
    }

}
