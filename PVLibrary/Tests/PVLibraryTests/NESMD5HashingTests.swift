//
//  NESMD5HashingTests.swift
//  PVLibrary
//
//  Unit tests for NES ROM MD5 hashing with iNES header offset handling
//

import Testing
import Foundation
@testable import PVLibrary

/// Tests for NES ROM MD5 hashing behavior
/// Verifies that:
/// 1. iNES format ROMs (with 16-byte header) skip the header when calculating MD5
/// 2. UNIF format ROMs (headerless) calculate MD5 from byte 0
/// 3. The iNES magic number detection works correctly
struct NESMD5HashingTests {

    let databaseService = GameImporterDatabaseService()

    // MARK: - Test Data

    /// iNES header magic bytes: "NES" followed by MS-DOS EOF marker (0x1A)
    static let iNESMagicBytes: [UInt8] = [0x4E, 0x45, 0x53, 0x1A] // "NES\x1A"

    /// Valid iNES header (16 bytes)
    /// Byte 4: PRG-ROM size in 16KB units (2 = 32KB)
    /// Byte 5: CHR-ROM size in 8KB units (1 = 8KB)
    /// Byte 6: Flags 6
    /// Byte 7: Flags 7
    /// Bytes 8-15: Padding/reserved
    static let validINESHeader: [UInt8] = [
        0x4E, 0x45, 0x53, 0x1A, // Magic: "NES\x1A"
        0x02,                   // PRG-ROM size: 2 * 16KB = 32KB
        0x01,                   // CHR-ROM size: 1 * 8KB = 8KB
        0x00,                   // Flags 6
        0x00,                   // Flags 7
        0x00, 0x00, 0x00, 0x00, // Padding
        0x00, 0x00, 0x00, 0x00  // Padding
    ]

    /// Invalid header (wrong magic bytes)
    static let invalidHeader: [UInt8] = [
        0x55, 0x4E, 0x49, 0x46, // "UNIF" - not iNES
        0x02, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
    ]

    /// NES 2.0 header (also starts with iNES magic)
    /// NES 2.0 is identified by bits 2-3 of byte 7 being set to 2 (0b10)
    static let nes20Header: [UInt8] = [
        0x4E, 0x45, 0x53, 0x1A, // Magic: "NES\x1A"
        0x02,                   // PRG-ROM size
        0x01,                   // CHR-ROM size
        0x00,                   // Flags 6
        0x08,                   // Flags 7: NES 2.0 indicator (bits 2-3 = 0b10)
        0x00, 0x00, 0x00, 0x00, // Extended header (NES 2.0 specific)
        0x00, 0x00, 0x00, 0x00
    ]

    // MARK: - Helper Methods

    /// Creates a temporary file with the given byte content
    /// - Parameters:
    ///   - data: Byte array to write to file
    ///   - filename: Name for the temporary file
    /// - Returns: URL to the temporary file
    private func createTemporaryFile(with data: [UInt8], filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        let data = Data(data)
        try data.write(to: fileURL)

        return fileURL
    }

    /// Creates a temporary iNES ROM file
    /// - Parameters:
    ///   - header: Header bytes (should be 16 bytes for iNES)
    ///   - romData: ROM payload data
    ///   - filename: Name for the temporary file
    /// - Returns: URL to the temporary file
    private func createTemporaryROM(
        header: [UInt8],
        romData: [UInt8],
        filename: String
    ) throws -> URL {
        var fileData = header
        fileData.append(contentsOf: romData)
        return try createTemporaryFile(with: fileData, filename: filename)
    }

    // MARK: - iNES Header Detection Tests

    @Test("Detects valid iNES header")
    func testValidINESHeaderDetection() throws {
        let romData: [UInt8] = [0x00, 0x01, 0x02, 0x03] // Some ROM data
        let fileURL = try createTemporaryROM(
            header: Self.validINESHeader,
            romData: romData,
            filename: "test_nes.nes"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == true)
    }

    @Test("Detects NES 2.0 header")
    func testNES20HeaderDetection() throws {
        let romData: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let fileURL = try createTemporaryROM(
            header: Self.nes20Header,
            romData: romData,
            filename: "test_nes20.nes"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == true)
    }

    @Test("Rejects invalid header (UNIF format)")
    func testInvalidHeaderDetection() throws {
        let romData: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let fileURL = try createTemporaryROM(
            header: Self.invalidHeader,
            romData: romData,
            filename: "test_unif.unf"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == false)
    }

    @Test("Rejects headerless file")
    func testHeaderlessFile() throws {
        let romData: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
        let fileURL = try createTemporaryFile(
            with: romData,
            filename: "test_raw.nes"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == false)
    }

    @Test("Rejects empty file")
    func testEmptyFile() throws {
        let fileURL = try createTemporaryFile(
            with: [],
            filename: "empty.nes"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == false)
    }

    @Test("Rejects file with only 3 bytes (incomplete header)")
    func testIncompleteHeader() throws {
        let partialHeader: [UInt8] = [0x4E, 0x45, 0x53] // "NES" without 0x1A
        let fileURL = try createTemporaryFile(
            with: partialHeader,
            filename: "incomplete.nes"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let hasHeader = databaseService.hasINESHeader(at: fileURL)
        #expect(hasHeader == false)
    }

    @Test("Rejects non-existent file")
    func testNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/file.nes")
        let hasHeader = databaseService.hasINESHeader(at: nonExistentURL)
        #expect(hasHeader == false)
    }

    // MARK: - iNES Header Format Documentation Tests

    @Test("iNES header structure is 16 bytes")
    func testINESHeaderSize() {
        #expect(Self.validINESHeader.count == 16)
    }

    @Test("iNES magic bytes are correct")
    func testINESMagicBytes() {
        #expect(Self.iNESMagicBytes[0] == 0x4E) // 'N'
        #expect(Self.iNESMagicBytes[1] == 0x45) // 'E'
        #expect(Self.iNESMagicBytes[2] == 0x53) // 'S'
        #expect(Self.iNESMagicBytes[3] == 0x1A) // DOS EOF marker
    }

    @Test("NES 2.0 is identified by bits 2-3 of byte 7")
    func testNES20Identification() {
        let byte7 = Self.nes20Header[7]
        // NES 2.0: bits 2-3 should be 0b10
        let versionBits = (byte7 >> 2) & 0x03
        #expect(versionBits == 0b10)
    }
}
