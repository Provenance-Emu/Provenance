// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipPackInfo {

    let packPosition: Int
    let numPackStreams: Int
    private(set) var packSizes = [Int]()
    private(set) var digests = [UInt32?]()

    init(_ bitReader: MsbBitReader) throws {
        packPosition = bitReader.szMbd()
        numPackStreams = bitReader.szMbd()

        var type = bitReader.byte()

        if type == 0x09 {
            for _ in 0..<numPackStreams {
                packSizes.append(bitReader.szMbd())
            }
            type = bitReader.byte()
        }

        if type == 0x0A {
            let definedBits = bitReader.defBits(count: numPackStreams)
            bitReader.align()

            for bit in definedBits {
                if bit == 1 {
                    digests.append(bitReader.uint32())
                } else {
                    digests.append(nil)
                }
            }

            type = bitReader.byte()
        }

        guard type == 0x00
            else { throw SevenZipError.internalStructureError }
    }

}
