// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipCoderInfo {

    let numFolders: Int

    let external: UInt8
    private(set) var folders = [SevenZipFolder]()

    init() {
        numFolders = 0
        external = 0
    }

    init(_ bitReader: MsbBitReader) throws {
        var type = bitReader.byte()
        guard type == 0x0B else { throw SevenZipError.internalStructureError }

        numFolders = bitReader.szMbd()
        external = bitReader.byte()

        guard external == 0
            else { throw SevenZipError.externalNotSupported }

        for _ in 0..<numFolders {
            folders.append(try SevenZipFolder(bitReader))
        }

        type = bitReader.byte()
        guard type == 0x0C else { throw SevenZipError.internalStructureError }

        for folder in folders {
            for _ in 0..<folder.totalOutputStreams {
                folder.unpackSizes.append(bitReader.szMbd())
            }
        }

        type = bitReader.byte()

        if type == 0x0A {
            let definedBits = bitReader.defBits(count: numFolders)
            bitReader.align()

            for i in 0..<numFolders where definedBits[i] == 1 {
                folders[i].crc = bitReader.uint32()
            }

            type = bitReader.byte()
        }

        guard type == 0x00
            else { throw SevenZipError.internalStructureError }
    }
}
