//
//  ZIPFoundationPerformanceTests.swift
//  ZIPFoundation
//
//  Copyright © 2017 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/LICENSE for license information.
//

import XCTest
@testable import ZIPFoundation

extension ZIPFoundationTests {
    func testPerformanceWriteUncompressed() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        measure {
            do {
                try archive.addEntry(with: entryName, type: .file,
                                     uncompressedSize: UInt32(size),
                                     compressionMethod: .none,
                                     provider: { (position, bufferSize) -> Data in
                                        let upperBound = Swift.min(size, position + bufferSize)
                                        let range = Range(uncheckedBounds: (lower: position, upper: upperBound))
                                        return data.subdata(in: range)
                })
            } catch {
                XCTFail("Failed to add large entry to uncompressed archive with error : \(error)")
            }
        }
    }

    func testPerformanceReadUncompressed() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        do {
            try archive.addEntry(with: entryName, type: .file,
                                 uncompressedSize: UInt32(size),
                                 compressionMethod: .none,
                                 provider: { (position, bufferSize) -> Data in
                                    let upperBound = Swift.min(size, position + bufferSize)
                                    let range = Range(uncheckedBounds: (lower: position, upper: upperBound))
                                    return data.subdata(in: range)
            })
        } catch {
            XCTFail("Failed to add large entry to uncompressed archive with error : \(error)")
        }
        measure {
            do {
                guard let entry = archive[entryName] else {
                    XCTFail("Failed to read entry.")
                    return
                }
                _ = try archive.extract(entry, consumer: {_ in })
            } catch {
                XCTFail("Failed to read large entry from uncompressed archive")
            }
        }
    }

    func testPerformanceWriteCompressed() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        measure {
            do {
                try archive.addEntry(with: entryName, type: .file,
                                     uncompressedSize: UInt32(size),
                                     compressionMethod: .deflate,
                                     provider: { (position, bufferSize) -> Data in
                                        let upperBound = Swift.min(size, position + bufferSize)
                                        let range = Range(uncheckedBounds: (lower: position, upper: upperBound))
                                        return data.subdata(in: range)
                })
            } catch {
                XCTFail("Failed to add large entry to compressed archive with error : \(error)")
            }
        }
    }

    func testPerformanceReadCompressed() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        do {
            try archive.addEntry(with: entryName, type: .file,
                                 uncompressedSize: UInt32(size),
                                 compressionMethod: .deflate,
                                 provider: { (position, bufferSize) -> Data in
                                    let upperBound = Swift.min(size, position + bufferSize)
                                    let range = Range(uncheckedBounds: (lower: position, upper: upperBound))
                                    return data.subdata(in: range)
            })
        } catch {
            XCTFail("Failed to add large entry to compressed archive with error : \(error)")
        }
        measure {
            do {
                guard let entry = archive[entryName] else {
                    XCTFail("Failed to read entry.")
                    return
                }
                _ = try archive.extract(entry, consumer: {_ in })
            } catch {
                XCTFail("Failed to read large entry from compressed archive")
            }
        }
    }
}
