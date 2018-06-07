//
//  ZIPFoundationTests.swift
//  ZIPFoundation
//
//  Copyright © 2017 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/LICENSE for license information.
//

import XCTest
@testable import ZIPFoundation

enum AdditionalDataError: Error {
    case encodingError
    case invalidDataError
}

class ZIPFoundationTests: XCTestCase {
    class var testBundle: Bundle {
        return Bundle(for: self)
    }

    static var tempZipDirectoryURL: URL = {
        let processInfo = ProcessInfo.processInfo
        var tempZipDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        tempZipDirectory.appendPathComponent("ZipTempDirectory")
        // We use a unique path to support parallel test runs via
        // "swift test --parallel"
        // When using --parallel, setUp() and tearDown() are called 
        // multiple times.
        tempZipDirectory.appendPathComponent(processInfo.globallyUniqueString)
        return tempZipDirectory
    }()

    static var resourceDirectoryURL: URL {
        var resourceDirectoryURL = URL(fileURLWithPath: #file)
        resourceDirectoryURL.deleteLastPathComponent()
        resourceDirectoryURL.appendPathComponent("Resources")
        return resourceDirectoryURL
    }

    override class func setUp() {
        super.setUp()
        do {
            let fileManager = FileManager()
            if fileManager.fileExists(atPath: tempZipDirectoryURL.path) {
                try fileManager.removeItem(at: tempZipDirectoryURL)
            }
            try fileManager.createDirectory(at: tempZipDirectoryURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            XCTFail("Unexpected error while trying to set up test resources.")
        }
    }

    override class func tearDown() {
        do {
            let fileManager = FileManager()
            try fileManager.removeItem(at: tempZipDirectoryURL)
        } catch {
            XCTFail("Unexpected error while trying to clean up test resources.")
        }
        super.tearDown()
    }

    func testArchiveReadErrorConditions() {
        let nonExistantURL = URL(fileURLWithPath: "/nothing")
        let nonExistantArchive = Archive(url: nonExistantURL, accessMode: .read)
        XCTAssertNil(nonExistantArchive)
        var unreadableArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let processInfo = ProcessInfo.processInfo
        unreadableArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
        let noPermissionAttributes = [FileAttributeKey.posixPermissions: NSNumber(value: Int16(0o000))]
        let fileManager = FileManager()
        var result = fileManager.createFile(atPath: unreadableArchiveURL.path, contents: nil,
                                                    attributes: noPermissionAttributes)
        XCTAssert(result == true)
        let unreadableArchive = Archive(url: unreadableArchiveURL, accessMode: .read)
        XCTAssertNil(unreadableArchive)
        var noEndOfCentralDirectoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        noEndOfCentralDirectoryArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
        let fullPermissionAttributes = [FileAttributeKey.posixPermissions: NSNumber(value: defaultFilePermissions)]
        result = fileManager.createFile(atPath: noEndOfCentralDirectoryArchiveURL.path, contents: nil,
                                                attributes: fullPermissionAttributes)
        XCTAssert(result == true)
        let noEndOfCentralDirectoryArchive = Archive(url: noEndOfCentralDirectoryArchiveURL,
                                                     accessMode: .read)
        XCTAssertNil(noEndOfCentralDirectoryArchive)
    }

    func testArchiveIteratorErrorConditions() {
        var didFailToMakeIteratorAsExpected = true
        // Construct an archive that only contains an EndOfCentralDirectoryRecord
        // with a number of entries > 0.
        // While the initializer is expected to work for such archives, iterator creation
        // should fail.
        let invalidCentralDirECDS: [UInt8] = [0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
                                              0x01, 0x00, 0x01, 0x00, 0x5A, 0x00, 0x00, 0x00,
                                              0x2A, 0x00, 0x00, 0x00, 0x00, 0x00]
        let invalidCentralDirECDSData = Data(bytes: invalidCentralDirECDS)
        let processInfo = ProcessInfo.processInfo
        var invalidCentralDirArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        invalidCentralDirArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
        let fileManager = FileManager()
        let result = fileManager.createFile(atPath: invalidCentralDirArchiveURL.path,
                                                    contents: invalidCentralDirECDSData,
                                                    attributes: nil)
        XCTAssert(result == true)
        guard let invalidCentralDirArchive = Archive(url: invalidCentralDirArchiveURL,
                                                     accessMode: .read) else {
                                                        XCTFail("Failed to read archive.")
                                                        return
        }
        for _ in invalidCentralDirArchive {
            didFailToMakeIteratorAsExpected = false
        }
        XCTAssertTrue(didFailToMakeIteratorAsExpected)
        let archive = self.archive(for: #function, mode: .read)
        do {
            var invalidLocalFHArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
            invalidLocalFHArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
            var invalidLocalFHArchiveData = try Data(contentsOf: archive.url)
            // Construct an archive with a corrupt LocalFileHeader.
            // While the initializer is expected to work for such archives, iterator creation
            // should fail.
            invalidLocalFHArchiveData[26] = 0xFF
            try invalidLocalFHArchiveData.write(to: invalidLocalFHArchiveURL)
            guard let invalidLocalFHArchive = Archive(url: invalidLocalFHArchiveURL,
                                                      accessMode: .read) else {
                                                        XCTFail("Failed to read local file header.")
                                                        return
            }
            for _ in invalidLocalFHArchive {
                didFailToMakeIteratorAsExpected = false
            }
        } catch {
            XCTFail("Unexpected error while testing iterator error conditions.")
        }
        XCTAssertTrue(didFailToMakeIteratorAsExpected)
    }

    func testArchiveInvalidDataErrorConditions() {
        let emptyECDR = Archive.EndOfCentralDirectoryRecord(data: Data(),
                                                            additionalDataProvider: {_ -> Data in
                                                                return Data() })
        XCTAssertNil(emptyECDR)
        let invalidECDRData = Data(count: 22)
        let invalidECDR = Archive.EndOfCentralDirectoryRecord(data: invalidECDRData,
                                                              additionalDataProvider: {_ -> Data in
                                                                return Data() })
        XCTAssertNil(invalidECDR)
        let ecdrInvalidCommentBytes: [UInt8] = [0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
                                                0x01, 0x00, 0x01, 0x00, 0x5A, 0x00, 0x00, 0x00,
                                                0x2A, 0x00, 0x00, 0x00, 0x00, 0x00]
        let invalidECDRCommentData = Data(bytes: ecdrInvalidCommentBytes)
        let invalidECDRComment = Archive.EndOfCentralDirectoryRecord(data: invalidECDRCommentData,
                                                                     additionalDataProvider: {_ -> Data in
                                                                        throw AdditionalDataError.invalidDataError })
        XCTAssertNil(invalidECDRComment)
        let ecdrInvalidCommentLengthBytes: [UInt8] = [0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
                                                      0x01, 0x00, 0x01, 0x00, 0x5A, 0x00, 0x00, 0x00,
                                                      0x2A, 0x00, 0x00, 0x00, 0x00, 0x01]
        let invalidECDRCommentLengthData = Data(bytes: ecdrInvalidCommentLengthBytes)
        let invalidECDRCommentLength = Archive.EndOfCentralDirectoryRecord(data: invalidECDRCommentLengthData,
                                                                           additionalDataProvider: {_ -> Data in
                                                                            return Data() })
        XCTAssertNil(invalidECDRCommentLength)
    }

    // MARK: - Helpers

    func archive(for testFunction: String, mode: Archive.AccessMode) -> Archive {
        var sourceArchiveURL = ZIPFoundationTests.resourceDirectoryURL
        sourceArchiveURL.appendPathComponent(testFunction.replacingOccurrences(of: "()", with: ""))
        sourceArchiveURL.appendPathExtension("zip")
        var destinationArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        destinationArchiveURL.appendPathComponent(sourceArchiveURL.lastPathComponent)
        do {
            if mode != .create {
                let fileManager = FileManager()
                try fileManager.copyItem(at: sourceArchiveURL, to: destinationArchiveURL)
            }
            guard let archive = Archive(url: destinationArchiveURL, accessMode: mode) else {
                throw Archive.ArchiveError.unreadableArchive
            }
            return archive
        } catch {
            XCTFail("Failed to get test archive '\(destinationArchiveURL.lastPathComponent)'")
            type(of: self).tearDown()
            preconditionFailure()
        }
    }

    func pathComponent(for testFunction: String) -> String {
        return testFunction.replacingOccurrences(of: "()", with: "")
    }

    func resourceURL(for testFunction: String, pathExtension: String) -> URL {
        var sourceAssetURL = ZIPFoundationTests.resourceDirectoryURL
        sourceAssetURL.appendPathComponent(testFunction.replacingOccurrences(of: "()", with: ""))
        sourceAssetURL.appendPathExtension(pathExtension)
        var destinationAssetURL = ZIPFoundationTests.tempZipDirectoryURL
        destinationAssetURL.appendPathComponent(sourceAssetURL.lastPathComponent)
        do {
            let fileManager = FileManager()
            try fileManager.copyItem(at: sourceAssetURL, to: destinationAssetURL)
            return destinationAssetURL
        } catch {
            XCTFail("Failed to get test resource '\(destinationAssetURL.lastPathComponent)'")
            type(of: self).tearDown()
            preconditionFailure()
        }
    }

    func createDirectory(for testFunction: String) -> URL {
        let fileManager = FileManager()
        var URL = ZIPFoundationTests.tempZipDirectoryURL
        URL = URL.appendingPathComponent(self.pathComponent(for: testFunction))
        do {
            try fileManager.createDirectory(at: URL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to get create directory for test function:\(testFunction)")
            type(of: self).tearDown()
            preconditionFailure()
        }
        return URL
    }

}

extension ZIPFoundationTests {
    // From https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass
                .defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount,
                           "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

    static var allTests: [(String, (ZIPFoundationTests) -> () throws -> Void)] {
        return [
            ("testArchiveAddEntryErrorConditions", testArchiveAddEntryErrorConditions),
            ("testArchiveCreateErrorConditions", testArchiveCreateErrorConditions),
            ("testArchiveInvalidDataErrorConditions", testArchiveInvalidDataErrorConditions),
            ("testArchiveIteratorErrorConditions", testArchiveIteratorErrorConditions),
            ("testArchiveReadErrorConditions", testArchiveReadErrorConditions),
            ("testArchiveUpdateErrorConditions", testArchiveUpdateErrorConditions),
            ("testCorruptFileErrorConditions", testCorruptFileErrorConditions),
            ("testCorruptSymbolicLinkErrorConditions", testCorruptSymbolicLinkErrorConditions),
            ("testCreateArchiveAddCompressedEntry", testCreateArchiveAddCompressedEntry),
            ("testCreateArchiveAddDirectory", testCreateArchiveAddDirectory),
            ("testCreateArchiveAddEntryErrorConditions", testCreateArchiveAddEntryErrorConditions),
            ("testCreateArchiveAddLargeCompressedEntry", testCreateArchiveAddLargeCompressedEntry),
            ("testCreateArchiveAddLargeUncompressedEntry", testCreateArchiveAddLargeUncompressedEntry),
            ("testCreateArchiveAddSymbolicLink", testCreateArchiveAddSymbolicLink),
            ("testCreateArchiveAddTooLargeUncompressedEntry", testCreateArchiveAddTooLargeUncompressedEntry),
            ("testCreateArchiveAddUncompressedEntry", testCreateArchiveAddUncompressedEntry),
            ("testDirectoryCreationHelperMethods", testDirectoryCreationHelperMethods),
            ("testEntryInvalidAdditionalDataErrorConditions", testEntryInvalidAdditionalDataErrorConditions),
            ("testEntryInvalidPathEncodingErrorConditions", testEntryInvalidPathEncodingErrorConditions),
            ("testEntryInvalidSignatureErrorConditions", testEntryInvalidSignatureErrorConditions),
            ("testEntryMissingDataDescriptorErrorCondition", testEntryMissingDataDescriptorErrorCondition),
            ("testEntryTypeDetectionHeuristics", testEntryTypeDetectionHeuristics),
            ("testEntryWrongDataLengthErrorConditions", testEntryWrongDataLengthErrorConditions),
            ("testExtractCompressedDataDescriptorArchive", testExtractCompressedDataDescriptorArchive),
            ("testExtractCompressedFolderEntries", testExtractCompressedFolderEntries),
            ("testExtractEncryptedArchiveErrorConditions", testExtractEncryptedArchiveErrorConditions),
            ("testExtractUncompressedEntryCancelation", testExtractUncompressedEntryCancelation),
            ("testExtractCompressedEntryCancelation", testExtractCompressedEntryCancelation),
            ("testExtractErrorConditions", testExtractErrorConditions),
            ("testExtractMSDOSArchive", testExtractMSDOSArchive),
            ("testExtractUncompressedDataDescriptorArchive", testExtractUncompressedDataDescriptorArchive),
            ("testExtractUncompressedFolderEntries", testExtractUncompressedFolderEntries),
            ("testExtractZIP64ArchiveErrorConditions", testExtractZIP64ArchiveErrorConditions),
            ("testFileAttributeHelperMethods", testFileAttributeHelperMethods),
            ("testFileModificationDate", testFileModificationDate),
            ("testFileModificationDateHelperMethods", testFileModificationDateHelperMethods),
            ("testFilePermissionErrorConditions", testFilePermissionErrorConditions),
            ("testFilePermissionHelperMethods", testFilePermissionHelperMethods),
            ("testFileSizeHelperMethods", testFileSizeHelperMethods),
            ("testFileTypeHelperMethods", testFileTypeHelperMethods),
            ("testInvalidCompressionMethodErrorConditions", testInvalidCompressionMethodErrorConditions),
            ("testPerformanceReadCompressed", testPerformanceReadCompressed),
            ("testPerformanceReadUncompressed", testPerformanceReadUncompressed),
            ("testPerformanceWriteCompressed", testPerformanceWriteCompressed),
            ("testPerformanceWriteUncompressed", testPerformanceWriteUncompressed),
            ("testPOSIXPermissions", testPOSIXPermissions),
            ("testProgressHelpers", testProgressHelpers),
            ("testReadChunkErrorConditions", testReadChunkErrorConditions),
            ("testReadStructureErrorConditions", testReadStructureErrorConditions),
            ("testRemoveCompressedEntry", testRemoveCompressedEntry),
            ("testRemoveDataDescriptorCompressedEntry", testRemoveDataDescriptorCompressedEntry),
            ("testRemoveEntryErrorConditions", testRemoveEntryErrorConditions),
            ("testRemoveUncompressedEntry", testRemoveUncompressedEntry),
            ("testUnzipItem", testUnzipItem),
            ("testUnzipItemErrorConditions", testUnzipItemErrorConditions),
            ("testWriteChunkErrorConditions", testWriteChunkErrorConditions),
            ("testZipItem", testZipItem),
            ("testZipItemErrorConditions", testZipItemErrorConditions),
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests)
        ] + darwinOnlyTests
    }

    static var darwinOnlyTests: [(String, (ZIPFoundationTests) -> () throws -> Void)] {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return [
            ("testZipItemProgress", testZipItemProgress),
            ("testUnzipItemProgress", testUnzipItemProgress),
            ("testRemoveEntryProgress", testRemoveEntryProgress),
            ("testArchiveAddUncompressedEntryProgress", testArchiveAddUncompressedEntryProgress),
            ("testArchiveAddCompressedEntryProgress", testArchiveAddCompressedEntryProgress)
        ]
        #else
        return []
        #endif
    }
}

extension Archive {
    func checkIntegrity() -> Bool {
        var isCorrect = false
        do {
            for entry in self {
                let checksum = try self.extract(entry, consumer: { _ in })
                isCorrect = checksum == entry.checksum
                guard isCorrect else { break }
            }
        } catch {
            return false
        }
        return isCorrect
    }
}

extension Data {
    static func makeRandomData(size: Int) -> Data {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            let bytes = [UInt32](repeating: 0, count: size).map { _ in arc4random() }
        #else
            let bytes = [UInt32](repeating: 0, count: size).map { _ in random() }
        #endif
        return Data(bytes: bytes, count: size)
    }
}
