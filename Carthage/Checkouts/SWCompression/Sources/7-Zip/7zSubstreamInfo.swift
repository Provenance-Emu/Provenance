// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipSubstreamInfo {

    var numUnpackStreamsInFolders = [Int]()
    var unpackSizes = [Int]()
    var digests = [UInt32?]()

    init(_ bitReader: MsbBitReader, _ coderInfo: SevenZipCoderInfo) throws {
        var totalUnpackStreams = coderInfo.folders.count

        var type = bitReader.byte()

        if type == 0x0D {
            totalUnpackStreams = 0
            for folder in coderInfo.folders {
                let numStreams = bitReader.szMbd()
                folder.numUnpackSubstreams = numStreams
                totalUnpackStreams += numStreams
            }
            type = bitReader.byte()
        }

        for folder in coderInfo.folders {
            if folder.numUnpackSubstreams == 0 {
                continue
            }
            var sum = 0
            if type == 0x09 {
                for _ in 0..<folder.numUnpackSubstreams - 1 {
                    let size = bitReader.szMbd()
                    unpackSizes.append(size)
                    sum += size
                }
            }
            unpackSizes.append(folder.unpackSize() - sum)
        }
        if type == 0x09 {
            type = bitReader.byte()
        }

        var totalDigests = 0
        for folder in coderInfo.folders {
            if folder.numUnpackSubstreams != 1 || folder.crc == nil {
                totalDigests += folder.numUnpackSubstreams
            }
        }

        if type == 0x0A {
            let definedBits = bitReader.defBits(count: totalDigests)
            bitReader.align()

            var missingCrcs = [UInt32?]()
            for i in 0..<totalDigests {
                if definedBits[i] == 1 {
                    missingCrcs.append(bitReader.uint32())
                } else {
                    missingCrcs.append(nil)
                }
            }

            var nextMissingCrc = 0
            for folder in coderInfo.folders {
                if folder.numUnpackSubstreams == 1 && folder.crc != nil {
                    digests.append(folder.crc)
                } else {
                    for _ in 0..<folder.numUnpackSubstreams {
                        digests.append(missingCrcs[nextMissingCrc])
                        nextMissingCrc += 1
                    }
                }
            }

            type = bitReader.byte()
        }

        guard type == 0x00
            else { throw SevenZipError.internalStructureError }
    }

}
