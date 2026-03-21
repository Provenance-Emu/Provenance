//
//  LynxHeaderDetectorTests.swift
//  PVHashingTests
//
//  Tests for Atari Lynx header detection.
//

import Testing
import Foundation
@testable import PVHashing

@Suite("Atari Lynx Header Detector Tests")
struct LynxHeaderDetectorTests {

    // MARK: - Magic Bytes Helpers

    /// Creates a Data buffer with the Lynx magic signature at offset 0.
    private func makeHeaderedData(romSize: Int = 16384) -> Data {
        var data = Data(repeating: 0x00, count: Int(LynxHeaderDetector.headerSize) + romSize)
        let magic: [UInt8] = [0x4C, 0x59, 0x4E, 0x58]
        for (i, byte) in magic.enumerated() {
            data[i] = byte
        }
        return data
    }

    /// Creates a Data buffer without the Lynx magic signature.
    private func makeHeaderlessData(size: Int = 16384) -> Data {
        Data(repeating: 0xCD, count: size)
    }

    // MARK: - Header Detection Tests

    @Test("Detect headered Lynx ROM returns offset 64")
    func testHeaderedROMReturnsOffset64() {
        let data = makeHeaderedData()
        let offset = LynxHeaderDetector.detectOffset(data: data)
        #expect(offset == 64, "Headered ROM should have 64-byte offset")
    }

    @Test("Detect headerless Lynx ROM returns offset 0")
    func testHeaderlessROMReturnsOffset0() {
        let data = makeHeaderlessData()
        let offset = LynxHeaderDetector.detectOffset(data: data)
        #expect(offset == 0, "Headerless ROM should have no offset")
    }

    @Test("hasLynxHeader returns true for valid magic bytes")
    func testHasLynxHeaderValidMagic() {
        let data = makeHeaderedData()
        #expect(LynxHeaderDetector.hasLynxHeader(data: data) == true)
    }

    @Test("hasLynxHeader returns false for headerless data")
    func testHasLynxHeaderNoMagic() {
        let data = makeHeaderlessData()
        #expect(LynxHeaderDetector.hasLynxHeader(data: data) == false)
    }

    @Test("hasLynxHeader returns false for wrong magic bytes")
    func testHasLynxHeaderWrongMagic() {
        // NES magic bytes, not Lynx
        let data = Data([0x4E, 0x45, 0x53, 0x1A] + [UInt8](repeating: 0x00, count: 60))
        #expect(LynxHeaderDetector.hasLynxHeader(data: data) == false)
    }

    @Test("hasLynxHeader returns false for data shorter than 4 bytes")
    func testHasLynxHeaderTooShort() {
        let data = Data([0x4C, 0x59])
        #expect(LynxHeaderDetector.hasLynxHeader(data: data) == false)
    }

    @Test("hasLynxHeader returns false for empty data")
    func testHasLynxHeaderEmptyData() {
        let data = Data()
        #expect(LynxHeaderDetector.hasLynxHeader(data: data) == false)
    }

    // MARK: - Data Shorter Than Header Size

    @Test("detectOffset(data:) returns headerSize (64) for magic-only buffer — data API does not enforce file size")
    func testDetectOffsetShortDataWithMagic() {
        // Only 4 bytes with magic - shorter than header size.
        // detectOffset(data:) only checks magic bytes; file-size validation is the
        // responsibility of detectOffset(for:), not the data-based API.
        let data = Data([0x4C, 0x59, 0x4E, 0x58])
        let offset = LynxHeaderDetector.detectOffset(data: data)
        #expect(offset == 64)
    }

    @Test("detectOffset(for:) returns 0 for file with magic but smaller than header size")
    func testFileWithMagicButTooSmallReturnsZero() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_truncated_\(UUID().uuidString).lnx")
        // Write only the magic bytes — far smaller than the 64-byte header
        let data = Data([0x4C, 0x59, 0x4E, 0x58])
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let offset = LynxHeaderDetector.detectOffset(for: fileURL)
        #expect(offset == 0, "Truncated file with magic but size < headerSize should return 0 to avoid hashing past EOF")
    }

    @Test("detectOffset returns 0 for empty data")
    func testDetectOffsetEmptyData() {
        let data = Data()
        let offset = LynxHeaderDetector.detectOffset(data: data)
        #expect(offset == 0, "Empty data should return no offset")
    }

    // MARK: - File-based Tests

    @Test("detectOffset for non-existent file returns nil")
    func testNonExistentFileReturnsNil() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/game.lnx")
        let offset = LynxHeaderDetector.detectOffset(for: nonExistentURL)
        #expect(offset == nil, "Non-existent file should return nil")
    }

    @Test("detectOffset for file with valid Lynx header returns 64")
    func testFileWithValidHeader() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_headered_\(UUID().uuidString).lnx")
        let data = makeHeaderedData()
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let offset = LynxHeaderDetector.detectOffset(for: fileURL)
        #expect(offset == 64, "File with valid Lynx header should return offset 64")
    }

    @Test("detectOffset for headerless file returns 0")
    func testFileWithoutHeader() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_headerless_\(UUID().uuidString).lnx")
        let data = makeHeaderlessData()
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let offset = LynxHeaderDetector.detectOffset(for: fileURL)
        #expect(offset == 0, "Headerless file should return offset 0")
    }

    // MARK: - Constants Tests

    @Test("Verify constants are correct")
    func testConstants() {
        #expect(LynxHeaderDetector.headerSize == 64)
        #expect(LynxHeaderDetector.magicBytes == [0x4C, 0x59, 0x4E, 0x58])
    }
}
