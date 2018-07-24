//
//  ZIPFoundationDataSerializationTests.swift
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
    func testReadStructureErrorConditions() {
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager()
        var fileURL = ZIPFoundationTests.tempZipDirectoryURL
        fileURL.appendPathComponent(processInfo.globallyUniqueString)
        let result = fileManager.createFile(atPath: fileURL.path, contents: Data(),
                                            attributes: nil)
        XCTAssert(result == true)
        let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: fileURL.path)
        let file: UnsafeMutablePointer<FILE> = fopen(fileSystemRepresentation, "rb")
        // Close the file to exercice the error path during readStructure that deals with
        // unreadable file data.
        fclose(file)
        let centralDirectoryStructure: Entry.CentralDirectoryStructure? = Data.readStruct(from: file, at: 0)
        XCTAssertNil(centralDirectoryStructure)
    }

    func testReadChunkErrorConditions() {
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager()
        var fileURL = ZIPFoundationTests.tempZipDirectoryURL
        fileURL.appendPathComponent(processInfo.globallyUniqueString)
        let result = fileManager.createFile(atPath: fileURL.path, contents: Data(),
                                            attributes: nil)
        XCTAssert(result == true)
        let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: fileURL.path)
        let file: UnsafeMutablePointer<FILE> = fopen(fileSystemRepresentation, "rb")
        // Close the file to exercice the error path during readChunk that deals with
        // unreadable file data.
        fclose(file)
        do {
            _ = try Data.readChunk(of: 10, from: file)
        } catch let error as Data.DataError {
            XCTAssert(error == .unreadableFile)
        } catch {
            XCTFail("Unexpected error while testing to read from a closed file.")
        }
    }

    func testWriteChunkErrorConditions() {
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager()
        var fileURL = ZIPFoundationTests.tempZipDirectoryURL
        fileURL.appendPathComponent(processInfo.globallyUniqueString)
        let result = fileManager.createFile(atPath: fileURL.path, contents: Data(),
                                            attributes: nil)
        XCTAssert(result == true)
        let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: fileURL.path)
        let file: UnsafeMutablePointer<FILE> = fopen(fileSystemRepresentation, "rb")
        // Close the file to exercice the error path during writeChunk that deals with
        // unwritable files.
        fclose(file)
        do {
            let dataWritten = try Data.write(chunk: Data(count: 10), to: file)
            XCTAssert(dataWritten == 0)
        } catch let error as Data.DataError {
            XCTAssert(error == .unwritableFile)
        } catch {
            XCTFail("Unexpected error while testing to write into a closed file.")
        }
    }
}
