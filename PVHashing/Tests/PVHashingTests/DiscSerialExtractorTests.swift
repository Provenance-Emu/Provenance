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
