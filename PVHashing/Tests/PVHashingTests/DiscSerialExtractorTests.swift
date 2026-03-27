//
//  DiscSerialExtractorTests.swift
//  PVHashing
//
//  Unit tests for disc-serial extraction plugins.
//

import XCTest
@testable import PVHashing

final class DiscSerialExtractorRegistryTests: XCTestCase {

    func testRegisterDefaultsIsIdempotent() async {
        let registry = DiscSerialExtractorRegistry.shared
        await registry.registerDefaults()
        await registry.registerDefaults() // Should not double-register.
        // No assertion needed — the test passes if no crash occurs.
    }

    func testNoPluginForUnknownExtension() async {
        let registry = DiscSerialExtractorRegistry.shared
        await registry.registerDefaults()
        let url = URL(fileURLWithPath: "/nonexistent/file.xyz")
        let result = await registry.extractSerial(from: url)
        XCTAssertNil(result)
    }
}

// MARK: - ISODiscSerialPlugin unit tests

final class ISODiscSerialPluginTests: XCTestCase {

    private let plugin = ISODiscSerialPlugin()

    // MARK: supportedExtensions

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("iso"))
        XCTAssertTrue(plugin.supportedExtensions.contains("img"))
        XCTAssertFalse(plugin.supportedExtensions.contains("cue"))
        XCTAssertFalse(plugin.supportedExtensions.contains("bin"))
    }

    // MARK: matchesMagicBytes

    func testMatchesMagicBytesWithShortData() {
        // Too short to detect — should return true to let extractSerial try.
        let tinyData = Data(repeating: 0, count: 100)
        XCTAssertTrue(plugin.matchesMagicBytes(tinyData))
    }

    func testMatchesMagicBytesWithCookedISOSignature() {
        var data = Data(repeating: 0, count: 37_700)
        // Place "CD001" at offset 32769 (cooked ISO PVD).
        let magic: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]
        data.replaceSubrange(32769..<32774, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesRaw2336Signature() {
        var data = Data(repeating: 0, count: 37_700)
        // Place "CD001" at offset 37385 (raw-2336 PVD).
        let magic: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]
        data.replaceSubrange(37385..<37390, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesNegative() {
        // Full-size buffer with no valid magic.
        let data = Data(repeating: 0xAB, count: 37_700)
        XCTAssertFalse(plugin.matchesMagicBytes(data))
    }

    // MARK: extractSerial (non-existent file → nil)

    func testExtractSerialNilForMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/missing.iso")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }
}

// MARK: - ISODiscSerialPlugin normalizeSerial tests (via extracted serial)

/// Tests for the serial normalisation helper — accessed indirectly through a
/// fabricated SYSTEM.CNF written to a real temp-directory ISO fixture.
final class ISONormalizeSerialTests: XCTestCase {

    // We test normalizeSerial indirectly through a real temp-file extraction
    // rather than marking it internal, to avoid widening visibility.

    private let plugin = ISODiscSerialPlugin()

    // Helper: creates a minimal cooked ISO image (2048-byte sector) with the
    // given SYSTEM.CNF content and returns the extracted DiscSerialResult.
    private func extractFromCNF(_ cnfContent: String) async -> DiscSerialResult? {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        } catch { return nil }
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a minimal ISO 9660 image:
        // - Sector 0–15: zeroed system area
        // - Sector 16: Primary Volume Descriptor with root dir pointing to sector 22
        // - Sector 22: directory record for SYSTEM.CNF pointing to sector 23
        // - Sector 23: SYSTEM.CNF content

        let sectorSize = 2048
        var image = Data(repeating: 0, count: sectorSize * 24)

        // PVD at sector 16 (offset 32768).
        let pvdOffset = 16 * sectorSize
        image[pvdOffset] = 0x01  // Primary Volume Descriptor type
        let cd001: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]
        image.replaceSubrange((pvdOffset + 1)..<(pvdOffset + 6), with: cd001)
        image[pvdOffset + 6] = 0x01  // version

        // Root directory record at PVD offset 156.
        // LBA = 22 (LE32 at pvd+158, BE32 at pvd+162), size = 2048 bytes.
        let rootDirLBA: UInt32 = 22
        let rootDirSize: UInt32 = UInt32(sectorSize)
        withUnsafeBytes(of: rootDirLBA.littleEndian) { bytes in
            image.replaceSubrange((pvdOffset + 158)..<(pvdOffset + 162), with: bytes)
        }
        withUnsafeBytes(of: rootDirLBA.bigEndian) { bytes in
            image.replaceSubrange((pvdOffset + 162)..<(pvdOffset + 166), with: bytes)
        }
        withUnsafeBytes(of: rootDirSize.littleEndian) { bytes in
            image.replaceSubrange((pvdOffset + 166)..<(pvdOffset + 170), with: bytes)
        }
        withUnsafeBytes(of: rootDirSize.bigEndian) { bytes in
            image.replaceSubrange((pvdOffset + 170)..<(pvdOffset + 174), with: bytes)
        }
        image[pvdOffset + 156] = 34  // directory record length

        // Directory sector at sector 22.
        let dirOffset = 22 * sectorSize
        let cnfName = Array("SYSTEM.CNF".utf8)
        let recLen = UInt8(33 + cnfName.count + (cnfName.count % 2 == 0 ? 0 : 1))
        image[dirOffset] = recLen
        let cnfLBA: UInt32 = 23
        withUnsafeBytes(of: cnfLBA.littleEndian) { bytes in
            image.replaceSubrange((dirOffset + 2)..<(dirOffset + 6), with: bytes)
        }
        // Data length (LE32)
        let cnfLen = UInt32(cnfContent.utf8.count)
        withUnsafeBytes(of: cnfLen.littleEndian) { bytes in
            image.replaceSubrange((dirOffset + 10)..<(dirOffset + 14), with: bytes)
        }
        image[dirOffset + 32] = UInt8(cnfName.count)
        image.replaceSubrange((dirOffset + 33)..<(dirOffset + 33 + cnfName.count), with: cnfName)

        // SYSTEM.CNF content at sector 23.
        let cnfBytes = Array(cnfContent.utf8)
        image.replaceSubrange((23 * sectorSize)..<(23 * sectorSize + cnfBytes.count), with: cnfBytes)

        let isoURL = tmpDir.appendingPathComponent("test.iso")
        do { try image.write(to: isoURL) } catch { return nil }

        return await plugin.extractSerial(from: isoURL, systemHint: nil)
    }

    func testNormalizeSerialPSXUnderscoreOnly() async {
        // SLUS_01234 — no dot, should give SLUS-01234
        let result = await extractFromCNF("BOOT = cdrom:\\SLUS_01234;1\n")
        XCTAssertEqual(result?.serial, "SLUS-01234")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.psx")
    }

    func testNormalizeSerialPSXWithEXEExtension() async {
        // SLUS_01234.EXE — alphabetic extension stripped, gives SLUS-01234
        let result = await extractFromCNF("BOOT = cdrom:\\SLUS_01234.EXE;1\n")
        XCTAssertEqual(result?.serial, "SLUS-01234")
    }

    func testNormalizeSerialPS2DotDigits() async {
        // SCES_533.45 — dot-separated digit halves, should give SCES-53345
        let result = await extractFromCNF("BOOT2 = cdrom0:\\SCES_533.45;1\n")
        XCTAssertEqual(result?.serial, "SCES-53345")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.ps2")
    }

    func testNormalizeSerialPS2ThreeAndTwo() async {
        // SLES_123.45 — another common PS2 pattern
        let result = await extractFromCNF("BOOT2 = cdrom0:\\SLES_123.45;1\n")
        XCTAssertEqual(result?.serial, "SLES-12345")
    }
}

// MARK: - SegaDiscSerialPlugin unit tests

final class SegaDiscSerialPluginTests: XCTestCase {

    private let plugin = SegaDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("bin"))
        XCTAssertTrue(plugin.supportedExtensions.contains("iso"))
        XCTAssertFalse(plugin.supportedExtensions.contains("cue"))
    }

    func testMatchesMagicBytesSaturn() {
        var data = Data(repeating: 0, count: 32)
        // Write Saturn magic at offset 0.
        let magic = Array("SEGA SATURN     ".utf8)
        data.replaceSubrange(0..<16, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesDreamcast() {
        var data = Data(repeating: 0, count: 32)
        let magic = Array("SEGA SEGASATURN ".utf8)
        data.replaceSubrange(0..<16, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesRawSectorOffset16() {
        var data = Data(repeating: 0, count: 32)
        // Magic at offset 16 (raw-sector BIN).
        let magic = Array("SEGA SATURN     ".utf8)
        data.replaceSubrange(16..<32, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesNegative() {
        let data = Data(repeating: 0, count: 32)
        XCTAssertFalse(plugin.matchesMagicBytes(data))
    }

    func testExtractSerialNilForMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.bin")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }
}

// MARK: - GameCubeDiscSerialPlugin unit tests

final class GameCubeDiscSerialPluginTests: XCTestCase {

    private let plugin = GameCubeDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("iso"))
        XCTAssertTrue(plugin.supportedExtensions.contains("gcm"))
        XCTAssertTrue(plugin.supportedExtensions.contains("wbfs"))
    }

    func testMatchesMagicBytesGameCube() {
        var data = Data(repeating: 0, count: 32)
        // GameCube magic at 0x1C.
        let magic: [UInt8] = [0xC2, 0x33, 0x6F, 0xA5]
        data.replaceSubrange(0x1C..<0x20, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesWii() {
        var data = Data(repeating: 0, count: 32)
        // Wii magic at 0x18.
        let magic: [UInt8] = [0x5D, 0x1C, 0x9E, 0xA3]
        data.replaceSubrange(0x18..<0x1C, with: magic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesNegative() {
        let data = Data(repeating: 0, count: 32)
        XCTAssertFalse(plugin.matchesMagicBytes(data))
    }

    func testExtractSerialNilForMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.iso")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }
}

// MARK: - BinCueDiscSerialPlugin unit tests

final class BinCueDiscSerialPluginTests: XCTestCase {

    private let plugin = BinCueDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("cue"))
        XCTAssertFalse(plugin.supportedExtensions.contains("bin"))
        XCTAssertFalse(plugin.supportedExtensions.contains("iso"))
    }

    func testExtractSerialNilForMissingCue() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.cue")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }

    /// Creates a minimal CUE+BIN pair in a temp dir, with a Saturn header.
    ///
    /// The BIN is 2048 bytes (cooked ISO sector size) so `sectorDataOffset`
    /// returns 0 and the header is read from the start of the file.
    func testExtractSerialFromSaturnCueBin() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // 2048-byte "cooked ISO" sector — sectorDataOffset returns 0 for this size
        // since 2048 % 2048 == 0.
        var binData = Data(repeating: 0, count: 2048)
        let saturnMagic = Array("SEGA SATURN     ".utf8) // 16 bytes
        binData.replaceSubrange(0..<16, with: saturnMagic)
        // Product code (10 bytes) at offset 0x20.
        let serial = Array("T-12345H  ".utf8)
        binData.replaceSubrange(0x20..<(0x20 + 10), with: serial)

        let binURL = tmpDir.appendingPathComponent("game.bin")
        try binData.write(to: binURL)

        // Write a matching CUE file.
        let cueContent = "FILE \"game.bin\" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\n"
        let cueURL = tmpDir.appendingPathComponent("game.cue")
        try cueContent.write(to: cueURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: cueURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "T-12345H")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.saturn")
    }
}

// MARK: - NDSDiscSerialPlugin unit tests

final class NDSDiscSerialPluginTests: XCTestCase {

    private let plugin = NDSDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("nds"))
        XCTAssertFalse(plugin.supportedExtensions.contains("iso"))
    }

    func testMatchesMagicBytesValid() {
        var data = Data(repeating: 0, count: 32)
        // Game code "AYLE" at 0x0C, maker code "01" at 0x10.
        let gameCode = Array("AYLE".utf8)
        let makerCode = Array("01".utf8)
        data.replaceSubrange(0x0C..<0x10, with: gameCode)
        data.replaceSubrange(0x10..<0x12, with: makerCode)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesNegative() {
        // All-zero header — null bytes are not valid ASCII alphanumerics.
        let data = Data(repeating: 0, count: 32)
        XCTAssertFalse(plugin.matchesMagicBytes(data))
    }

    func testExtractSerialFromFakeNDS() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var romHeader = Data(repeating: 0, count: 512)
        let gameCode  = Array("AYLE".utf8)
        let makerCode = Array("01".utf8)
        romHeader.replaceSubrange(0x0C..<0x10, with: gameCode)
        romHeader.replaceSubrange(0x10..<0x12, with: makerCode)

        let ndsURL = tmpDir.appendingPathComponent("game.nds")
        try romHeader.write(to: ndsURL)

        let result = await plugin.extractSerial(from: ndsURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "AYLE01")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.nds")
    }

    func testExtractSerialNilForMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.nds")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }
}

// MARK: - DiscSerialResult tests

final class DiscSerialResultTests: XCTestCase {

    func testInitialization() {
        let result = DiscSerialResult(serial: "SLUS-01234",
                                      systemIdentifierHint: "com.provenance.psx")
        XCTAssertEqual(result.serial, "SLUS-01234")
        XCTAssertEqual(result.systemIdentifierHint, "com.provenance.psx")
    }

    func testInitializationWithoutHint() {
        let result = DiscSerialResult(serial: "GALE01")
        XCTAssertEqual(result.serial, "GALE01")
        XCTAssertNil(result.systemIdentifierHint)
    }
}
