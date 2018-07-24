//
//  ZIPFoundationEntryTests.swift
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
    func testEntryWrongDataLengthErrorConditions() {
        let emptyCDS = Entry.CentralDirectoryStructure(data: Data(),
                                                       additionalDataProvider: {_ -> Data in
                                                        return Data() })
        XCTAssertNil(emptyCDS)
        let emptyLFH = Entry.LocalFileHeader(data: Data(),
                                             additionalDataProvider: {_ -> Data in
                                                return Data() })
        XCTAssertNil(emptyLFH)
        let emptyDD = Entry.DataDescriptor(data: Data(),
                                           additionalDataProvider: {_ -> Data in
                                            return Data() })
        XCTAssertNil(emptyDD)
    }

    func testEntryInvalidSignatureErrorConditions() {
        let invalidCDS = Entry.CentralDirectoryStructure(data: Data.init(count: Entry.CentralDirectoryStructure.size),
                                                         additionalDataProvider: {_ -> Data in
                                                            return Data() })
        XCTAssertNil(invalidCDS)
        let invalidLFH = Entry.LocalFileHeader(data: Data(count: Entry.LocalFileHeader.size),
                                               additionalDataProvider: {_ -> Data in
                                                return Data() })
        XCTAssertNil(invalidLFH)
    }

    func testEntryInvalidAdditionalDataErrorConditions() {
        let cdsBytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x03, 0x14, 0x00,
                                 0x08, 0x00, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        let invalidAddtionalDataCDS = Entry.CentralDirectoryStructure(data: Data(bytes: cdsBytes)) { _ -> Data in
            return Data()
        }
        XCTAssertNil(invalidAddtionalDataCDS)
        let lfhBytes: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x00,
                                 0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]
        let invalidAddtionalDataLFH = Entry.LocalFileHeader(data: Data(bytes: lfhBytes)) { _ -> Data in
            return Data()
        }
        XCTAssertNil(invalidAddtionalDataLFH)
        let cds2Bytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x03, 0x14, 0x00,
                                  0x08, 0x08, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                  0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                  0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                  0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        let cds2 = Entry.CentralDirectoryStructure(data: Data(bytes: cds2Bytes)) { _ -> Data in
            throw AdditionalDataError.encodingError
        }
        XCTAssertNil(cds2)
        let lfhBytes2: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x08,
                                  0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                  0x00, 0x00, 0x01, 0x00, 0x00, 0x00]
        let lfh2 = Entry.LocalFileHeader(data: Data(bytes: lfhBytes2)) { _ -> Data in
            throw AdditionalDataError.encodingError
        }
        XCTAssertNil(lfh2)
    }

    func testEntryInvalidPathEncodingErrorConditions() {
        // Use bytes that are invalid code units in UTF-8 to trigger failed initialization
        // of the path String.
        let invalidPathBytes: [UInt8] = [0xFF]
        let cdsBytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x03, 0x14, 0x00,
                                 0x08, 0x08, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        let cds = Entry.CentralDirectoryStructure(data: Data(bytes: cdsBytes)) { _ -> Data in
            return Data(bytes: invalidPathBytes)
        }
        let lfhBytes: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x08,
                                 0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]
        let lfh = Entry.LocalFileHeader(data: Data(bytes: lfhBytes)) { _ -> Data in
            return Data(bytes: invalidPathBytes)
        }
        guard let central = cds else {
            XCTFail("Failed to read central directory structure.")
            return
        }
        guard let local = lfh else {
            XCTFail("Failed to read local file header.")
            return
        }
        guard let entry = Entry(centralDirectoryStructure: central, localFileHeader: local, dataDescriptor: nil) else {
            XCTFail("Failed to read entry.")
            return
        }
        XCTAssertTrue(entry.path == "")
    }

    func testEntryMissingDataDescriptorErrorCondition() {
        let cdsBytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x03, 0x14, 0x00,
                                 0x08, 0x08, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        let cds = Entry.CentralDirectoryStructure(data: Data(bytes: cdsBytes)) { _ -> Data in
            return Data()
        }
        let lfhBytes: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x08,
                                 0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let lfh = Entry.LocalFileHeader(data: Data(bytes: lfhBytes)) { _ -> Data in
            return Data()
        }
        guard let central = cds else {
            XCTFail("Failed to read central directory structure.")
            return
        }
        guard let local = lfh else {
            XCTFail("Failed to read local file header.")
            return
        }
        guard let entry = Entry(centralDirectoryStructure: central, localFileHeader: local, dataDescriptor: nil) else {
            XCTFail("Failed to read entry.")
            return
        }
        XCTAssertTrue(entry.checksum == 0)
    }

    func testEntryTypeDetectionHeuristics() {
        // Set the upper byte of .versionMadeBy to 0x15.
        // This exercises the code path that deals with invalid OSTypes.
        let cdsBytes: [UInt8] = [0x50, 0x4b, 0x01, 0x02, 0x1e, 0x15, 0x14, 0x00,
                                 0x08, 0x08, 0x08, 0x00, 0xab, 0x85, 0x77, 0x47,
                                 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xb0, 0x11, 0x00, 0x00, 0x00, 0x00]
        let cds = Entry.CentralDirectoryStructure(data: Data(bytes: cdsBytes)) { _ -> Data in
            guard let pathData = "/".data(using: .utf8) else { throw AdditionalDataError.encodingError }
            return pathData
        }
        let lfhBytes: [UInt8] = [0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x08,
                                 0x08, 0x00, 0xab, 0x85, 0x77, 0x47, 0x00, 0x00,
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]
        let lfh = Entry.LocalFileHeader(data: Data(bytes: lfhBytes)) { _ -> Data in
            guard let pathData = "/".data(using: .utf8) else { throw AdditionalDataError.encodingError }
            return pathData
        }
        guard let central = cds else {
            XCTFail("Failed to read central directory structure.")
            return
        }
        guard let local = lfh else {
            XCTFail("Failed to read local file header.")
            return
        }
        guard let entry = Entry(centralDirectoryStructure: central, localFileHeader: local, dataDescriptor: nil) else {
            XCTFail("Failed to read entry.")
            return
        }
        XCTAssertTrue(entry.type == .directory)
    }
}
