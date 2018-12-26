// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    private static let testType: String = "7z"

    func test1() throws {
        let testData = try Constants.data(forTest: "test1", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test1")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xB4E89E84)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test2() throws {
        let testData = try Constants.data(forTest: "test2", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        let answer1Data = try Constants.data(forAnswer: "test1")

        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answer1Data.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xB4E89E84)

        XCTAssertEqual(entries[0].data, answer1Data)

        let answer4Data = try Constants.data(forAnswer: "test4")

        XCTAssertEqual(entries[1].info.name, "test4.answer")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, answer4Data.count)
        XCTAssertEqual(entries[1].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[1].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[1].info.modificationTime)
        XCTAssertNil(entries[1].info.accessTime)
        XCTAssertNil(entries[1].info.creationTime)
        XCTAssertEqual(entries[1].info.hasStream, true)
        XCTAssertEqual(entries[1].info.isEmpty, false)
        XCTAssertEqual(entries[1].info.isAnti, false)
        XCTAssertEqual(entries[1].info.crc, 0xAEF524A3)

        XCTAssertEqual(entries[1].data, answer4Data)
    }

    func test3() throws {
        let testData = try Constants.data(forTest: "test3", withType: SevenZipTests.testType)

        _ = try SevenZipContainer.info(container: testData)
        _ = try SevenZipContainer.open(container: testData)
    }

    func testAntiFile() throws {
        let testData = try Constants.data(forTest: "test_anti_file", withType: SevenZipTests.testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            if entry.info.name == "test_create/test4.answer" {
                XCTAssertEqual(entry.info.isAnti, true)
            } else {
                XCTAssertEqual(entry.info.isAnti, false)
            }
        }
    }

    func testMultiBlocks() throws {
        // Container was created with "solid" options set to "off" (-ms=off).
        let testData = try Constants.data(forTest: "test_multi_blocks", withType: SevenZipTests.testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testAllTimestamps() throws {
        // Container was created with "-mtc=on" and "-mta=on" options.
        let testData = try Constants.data(forTest: "test_all_timestamps", withType: SevenZipTests.testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            XCTAssertNotNil(entry.info.creationTime)
            XCTAssertNotNil(entry.info.accessTime)
            // Just in case...
            XCTAssertNotNil(entry.info.modificationTime)
        }
    }

    func testComplicatedCodingScheme() throws {
        // Container was created with these options: "-mf=BCJ -m0=Copy -m1=Deflate -m2=Delta -m3=LZMA -m4=LZMA2"
        let testData = try Constants.data(forTest: "test_complicated_coding_scheme", withType: SevenZipTests.testType)
        // In these test case the most important thing is that information about entries must be read correctly.
        _ = try SevenZipContainer.info(container: testData)

        // It is expected for `open(container:) function to throw `SevenZipError.compressionNotSupported`,
        //  because of the coders used.
        XCTAssertThrowsError(try SevenZipContainer.open(container: testData)) { error in
            XCTAssertEqual(error as? SevenZipError, SevenZipError.compressionNotSupported)
        }
    }

    func testEncryptedHeader() throws {
        // Container was created with "-mhe=on".
        let testData = try Constants.data(forTest: "test_encrypted_header", withType: SevenZipTests.testType)

        XCTAssertThrowsError(try SevenZipContainer.info(container: testData)) { error in
            XCTAssertEqual(error as? SevenZipError, SevenZipError.encryptionNotSupported)
        }

        // There is no point in testing `open(container:)` function, because we are unable to get even files' info.
    }

    func testSingleThread() throws {
        // Container was created with disabled multithreading options.
        // We check this just in case.
        let testData = try Constants.data(forTest: "test_single_thread", withType: SevenZipTests.testType)

        XCTAssertEqual(try SevenZipContainer.info(container: testData).count, 6)
        XCTAssertEqual(try SevenZipContainer.open(container: testData).count, 6)
    }

    func testBigContainer() throws {
        let testData = try Constants.data(forTest: "SWCompressionSourceCode", withType: SevenZipTests.testType)

        _ = try SevenZipContainer.info(container: testData)
        _ = try SevenZipContainer.open(container: testData)
    }

    func test7zBZip2() throws {
        // File in container compressed with BZip2.
        let testData = try Constants.data(forTest: "test_7z_bzip2", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xAEF524A3)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zDeflate() throws {
        // File in container compressed with Deflate.
        let testData = try Constants.data(forTest: "test_7z_deflate", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xAEF524A3)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zCopy() throws {
        // File in container is explicitly uncompressed.
        let testData = try Constants.data(forTest: "test_7z_copy", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xAEF524A3)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testUnicode() throws {
        let testData = try Constants.data(forTest: "test_unicode", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xA139BCEE)

        let answerData = try Constants.data(forAnswer: "текстовый файл")
        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        let testData = try Constants.data(forTest: "test_win", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, nil)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 0))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x10))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, false)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertNil(entries[0].info.crc)

        XCTAssertEqual(entries[0].data, nil)

        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].info.permissions, Permissions(rawValue: 0))
        XCTAssertEqual(entries[1].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[1].info.modificationTime)
        XCTAssertNil(entries[1].info.accessTime)
        XCTAssertNil(entries[1].info.creationTime)
        XCTAssertEqual(entries[1].info.hasStream, true)
        XCTAssertEqual(entries[1].info.isEmpty, false)
        XCTAssertEqual(entries[1].info.isAnti, false)
        XCTAssertEqual(entries[1].info.crc, 0x1273FBD3)

        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        let testData = try Constants.data(forTest: "test_empty_file", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, false)
        XCTAssertEqual(entries[0].info.isEmpty, true)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertNil(entries[0].info.crc)

        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        let testData = try Constants.data(forTest: "test_empty_dir", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, nil)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 493))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x10))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, false)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertNil(entries[0].info.crc)

        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        let testData = try Constants.data(forTest: "test_empty_cont", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

    func testDeltaFilter() throws {
        let testData = try Constants.data(forTest: "test_delta_filter", withType: SevenZipTests.testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)
        XCTAssertEqual(entries[0].info.hasStream, true)
        XCTAssertEqual(entries[0].info.isEmpty, false)
        XCTAssertEqual(entries[0].info.isAnti, false)
        XCTAssertEqual(entries[0].info.crc, 0xAEF524A3)

        XCTAssertEqual(entries[0].data, answerData)
    }

}
