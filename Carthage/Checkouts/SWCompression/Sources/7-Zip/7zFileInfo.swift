// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

class SevenZipFileInfo {

    struct File {
        var isEmptyStream = false
        var isEmptyFile = false
        var isAntiFile = false
        var name: String = ""
        var cTime: Date?
        var mTime: Date?
        var aTime: Date?
        var winAttributes: UInt32?
    }

    let numFiles: Int
    var files = [File]()

    var unknownProperties = [SevenZipProperty]()

    init(_ bitReader: MsbBitReader) throws {
        numFiles = bitReader.szMbd()
        for _ in 0..<numFiles {
            files.append(File())
        }

        var isEmptyStream: [UInt8]?
        var isEmptyFile: [UInt8]?
        var isAntiFile: [UInt8]?

        while true {
            let propertyType = bitReader.byte()
            if propertyType == 0 {
                break
            }
            let propertySize = bitReader.szMbd()
            switch propertyType {
            case 0x0E: // EmptyStream
                isEmptyStream = bitReader.bits(count: numFiles)
                bitReader.align()
            case 0x0F: // EmptyFile
                guard let emptyStreamCount = isEmptyStream?.filter({ $0 == 1 }).count
                    else { throw SevenZipError.internalStructureError }
                isEmptyFile = bitReader.bits(count: emptyStreamCount)
                bitReader.align()
            case 0x10: // AntiFile (used in backups to indicate that file was removed)
                guard let emptyStreamCount = isEmptyStream?.filter({ $0 == 1 }).count
                    else { throw SevenZipError.internalStructureError }
                isAntiFile = bitReader.bits(count: emptyStreamCount)
                bitReader.align()
            case 0x11: // File name
                let external = bitReader.byte()
                guard external == 0
                    else { throw SevenZipError.externalNotSupported }
                guard (propertySize - 1) & 1 == 0,
                    let names = String(bytes: bitReader.bytes(count: propertySize - 1), encoding: .utf16LittleEndian)
                    else { throw SevenZipError.internalStructureError }

                var nextFile = 0
                for name in names.split(separator: "\u{0}") {
                    files[nextFile].name = String(name)
                    nextFile += 1
                }

                guard nextFile == numFiles
                    else { throw SevenZipError.internalStructureError }
            case 0x12: // Creation time
                let timesDefined = bitReader.defBits(count: numFiles)
                bitReader.align()
                let external = bitReader.byte()
                guard external == 0
                    else { throw SevenZipError.externalNotSupported }

                for i in 0..<numFiles where timesDefined[i] == 1 {
                    files[i].cTime = Date(bitReader.uint64())
                }
            case 0x13: // Access time
                let timesDefined = bitReader.defBits(count: numFiles)
                bitReader.align()

                let external = bitReader.byte()
                guard external == 0
                    else { throw SevenZipError.externalNotSupported }

                for i in 0..<numFiles where timesDefined[i] == 1 {
                    files[i].aTime = Date(bitReader.uint64())
                }
            case 0x14: // Modification time
                let timesDefined = bitReader.defBits(count: numFiles)
                bitReader.align()

                let external = bitReader.byte()
                guard external == 0
                    else { throw SevenZipError.externalNotSupported }

                for i in 0..<numFiles where timesDefined[i] == 1 {
                    files[i].mTime = Date(bitReader.uint64())
                }
            case 0x15: // WinAttributes
                let attributesDefined = bitReader.defBits(count: numFiles)
                bitReader.align()

                let external = bitReader.byte()
                guard external == 0
                    else { throw SevenZipError.externalNotSupported }

                for i in 0..<numFiles where attributesDefined[i] == 1 {
                    files[i].winAttributes = bitReader.uint32()
                }
            case 0x18: // StartPos
                throw SevenZipError.startPosNotSupported
            case 0x19: // "Dummy". Used for alignment/padding.
                guard bitReader.size - bitReader.offset >= propertySize
                    else { throw SevenZipError.internalStructureError }
                bitReader.offset += propertySize
            default: // Unknown property
                guard bitReader.size - bitReader.offset >= propertySize
                    else { throw SevenZipError.internalStructureError }
                unknownProperties.append(SevenZipProperty(propertyType, propertySize,
                                                          bitReader.bytes(count: propertySize)))
            }
        }

        var emptyFileIndex = 0
        for i in 0..<numFiles {
            files[i].isEmptyStream = isEmptyStream?[i] == 1
            if files[i].isEmptyStream {
                files[i].isEmptyFile = isEmptyFile?[emptyFileIndex] == 1
                files[i].isAntiFile = isAntiFile?[emptyFileIndex] == 1
                emptyFileIndex += 1
            }
        }
    }

}
