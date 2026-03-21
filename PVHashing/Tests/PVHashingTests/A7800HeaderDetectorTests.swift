//
//  A7800HeaderDetectorTests.swift
//  PVHashingTests
//
//  Tests for Atari 7800 header detection.
//

import Testing
import Foundation
@testable import PVHashing

@Suite("Atari 7800 Header Detector Tests")
struct A7800HeaderDetectorTests {

    // MARK: - Magic Bytes Helpers

    /// Creates a Data buffer with the Atari 7800 magic signature at the correct offset.
    /// Byte 0 is 0x01, bytes 1-9 are "ATARI7800".
    private func makeHeaderedData(romSize: Int = 32768) -> Data {
        var data = Data(repeating: 0x00, count: Int(A7800HeaderDetector.headerSize) + romSize)
        data[0] = 0x01
        let magic: [UInt8] = [0x41, 0x54, 0x41, 0x52, 0x49, 0x37, 0x38, 0x30, 0x30]
        for (i, byte) in magic.enumerated() {
            data[1 + i] = byte
        }
        return data
    }

    /// Creates a Data buffer without the Atari 7800 magic signature.
    private func makeHeaderlessData(size: Int = 32768) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - Header Detection Tests

    @Test("Detect headered Atari 7800 ROM returns offset 128")
    func testHeaderedROMReturnsOffset128() {
        let data = makeHeaderedData()
        let offset = A7800HeaderDetector.detectOffset(data: data)
        #expect(offset == 128, "Headered ROM should have 128-byte offset")
    }

    @Test("Detect headerless Atari 7800 ROM returns offset 0")
    func testHeaderlessROMReturnsOffset0() {
        let data = makeHeaderlessData()
        let offset = A7800HeaderDetector.detectOffset(data: data)
        #expect(offset == 0, "Headerless ROM should have no offset")
    }

    @Test("hasA7800Header returns true for valid magic bytes")
    func testHasA7800HeaderValidMagic() {
        let data = makeHeaderedData()
        #expect(A7800HeaderDetector.hasA7800Header(data: data) == true)
    }

    @Test("hasA7800Header returns false for headerless data")
    func testHasA7800HeaderNoMagic() {
        let data = makeHeaderlessData()
        #expect(A7800HeaderDetector.hasA7800Header(data: data) == false)
    }

    @Test("hasA7800Header returns false for wrong magic bytes")
    func testHasA7800HeaderWrongMagic() {
        var data = Data(repeating: 0x00, count: 128)
        // Put wrong bytes at offset 1-9
        let wrongMagic: [UInt8] = [0x4E, 0x45, 0x53, 0x1A, 0x00, 0x00, 0x00, 0x00, 0x00]
        for (i, byte) in wrongMagic.enumerated() {
            data[1 + i] = byte
        }
        #expect(A7800HeaderDetector.hasA7800Header(data: data) == false)
    }

    @Test("hasA7800Header returns false for data shorter than 10 bytes")
    func testHasA7800HeaderTooShort() {
        let data = Data([0x01, 0x41, 0x54])
        #expect(A7800HeaderDetector.hasA7800Header(data: data) == false)
    }

    @Test("hasA7800Header returns false for empty data")
    func testHasA7800HeaderEmptyData() {
        let data = Data()
        #expect(A7800HeaderDetector.hasA7800Header(data: data) == false)
    }

    // MARK: - Data Shorter Than Header Size

    @Test("detectOffset returns headerSize (128) for data shorter than header size but with valid magic")
    func testDetectOffsetShortDataWithMagic() {
        // Only 10 bytes - has magic but no room for a full header
        var data = Data(repeating: 0x00, count: 10)
        data[0] = 0x01
        let magic: [UInt8] = [0x41, 0x54, 0x41, 0x52, 0x49, 0x37, 0x38, 0x30, 0x30]
        for (i, byte) in magic.enumerated() {
            data[1 + i] = byte
        }
        // Magic is present, so detectOffset should return headerSize regardless of data length
        let offset = A7800HeaderDetector.detectOffset(data: data)
        #expect(offset == 128)
    }

    @Test("detectOffset returns 0 for empty data")
    func testDetectOffsetEmptyData() {
        let data = Data()
        let offset = A7800HeaderDetector.detectOffset(data: data)
        #expect(offset == 0, "Empty data should return no offset")
    }

    // MARK: - File-based Tests

    @Test("detectOffset for non-existent file returns nil")
    func testNonExistentFileReturnsNil() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/game.a78")
        let offset = A7800HeaderDetector.detectOffset(for: nonExistentURL)
        #expect(offset == nil, "Non-existent file should return nil")
    }

    @Test("detectOffset for file with valid A7800 header returns 128")
    func testFileWithValidHeader() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_headered_\(UUID().uuidString).a78")
        let data = makeHeaderedData()
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let offset = A7800HeaderDetector.detectOffset(for: fileURL)
        #expect(offset == 128, "File with valid A7800 header should return offset 128")
    }

    @Test("detectOffset for headerless file returns 0")
    func testFileWithoutHeader() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_headerless_\(UUID().uuidString).a78")
        let data = makeHeaderlessData()
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let offset = A7800HeaderDetector.detectOffset(for: fileURL)
        #expect(offset == 0, "Headerless file should return offset 0")
    }

    // MARK: - Constants Tests

    @Test("Verify constants are correct")
    func testConstants() {
        #expect(A7800HeaderDetector.headerSize == 128)
        #expect(A7800HeaderDetector.magicBytes == [0x41, 0x54, 0x41, 0x52, 0x49, 0x37, 0x38, 0x30, 0x30])
    }
}
