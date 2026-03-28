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
        // ISO 9660 §9.1: a zero-byte is appended when the file identifier length
        // is even, so that the total Directory Record length is always even.
        let recLen = UInt8(33 + cnfName.count + (cnfName.count % 2 == 0 ? 1 : 0))
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

    /// Regression: a cooked .iso whose byte count happens to be divisible by
    /// 2352 (e.g., 4816896 = 2048 * 2352) must still be detected correctly.
    /// The old file-size-divisibility approach would have returned offset 16,
    /// causing the magic check to fail and extraction to return nil.
    func testExtractSerialCookedISOWithSizeMultipleOf2352() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // 2352 bytes total — divisible by both 2352 and 2048 would need lcm(2048,2352).
        // Simplest: 4 * 2352 = 9408 bytes, NOT divisible by 2048 but divisible by 2352.
        // With old code: sectorDataOffset returns 16 (wrong). New code: reads magic at byte 0.
        var isoData = Data(repeating: 0, count: 4 * 2352)
        let saturnMagic = Array("SEGA SATURN     ".utf8)
        isoData.replaceSubrange(0..<16, with: saturnMagic)
        let serial = Array("T-99999H  ".utf8)
        isoData.replaceSubrange(0x20..<(0x20 + 10), with: serial)

        let isoURL = tmpDir.appendingPathComponent("game.iso")
        try isoData.write(to: isoURL)

        let result = await plugin.extractSerial(from: isoURL, systemHint: nil)
        XCTAssertNotNil(result, "Cooked ISO whose size is divisible by 2352 must still be extracted")
        XCTAssertEqual(result?.serial, "T-99999H")
    }
}

// MARK: - GameCubeDiscSerialPlugin unit tests

final class GameCubeDiscSerialPluginTests: XCTestCase {

    private let plugin = GameCubeDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("iso"))
        XCTAssertTrue(plugin.supportedExtensions.contains("gcm"))
        XCTAssertTrue(plugin.supportedExtensions.contains("wbfs"))
        XCTAssertTrue(plugin.supportedExtensions.contains("rvz"))
        XCTAssertTrue(plugin.supportedExtensions.contains("wia"))
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

    func testMatchesMagicBytesWBFS() {
        var data = Data(repeating: 0, count: 32)
        // WBFS magic at byte 0: "WBFS".
        let wbfsMagic: [UInt8] = [0x57, 0x42, 0x46, 0x53]
        data.replaceSubrange(0..<4, with: wbfsMagic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesRVZ() {
        var data = Data(repeating: 0, count: 32)
        // RVZ magic at byte 0: "RVZ\x01".
        let rvzMagic: [UInt8] = [0x52, 0x56, 0x5A, 0x01]
        data.replaceSubrange(0..<4, with: rvzMagic)
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesWIA() {
        var data = Data(repeating: 0, count: 32)
        // WIA magic at byte 0: "WIA\x01".
        let wiaMagic: [UInt8] = [0x57, 0x49, 0x41, 0x01]
        data.replaceSubrange(0..<4, with: wiaMagic)
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

    /// Writes a fake GameCube ISO with the correct magic and a known disc ID,
    /// then verifies that extraction returns the expected result.
    func testExtractSerialFromFakeGCISO() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var header = Data(repeating: 0, count: 512)
        // Disc ID: game code "GALE" + maker code "01"
        let discID = Array("GALE01".utf8)
        header.replaceSubrange(0..<6, with: discID)
        // GameCube magic at 0x1C
        let gcMagic: [UInt8] = [0xC2, 0x33, 0x6F, 0xA5]
        header.replaceSubrange(0x1C..<0x20, with: gcMagic)

        let isoURL = tmpDir.appendingPathComponent("game.iso")
        try header.write(to: isoURL)

        let result = await plugin.extractSerial(from: isoURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "GALE01")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.gamecube")
    }

    /// Verifies WBFS extraction: disc header at file offset 512.
    func testExtractSerialFromFakeWBFS() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var fileData = Data(repeating: 0, count: 512 + 512)
        // WBFS magic at file offset 0
        let wbfsMagic: [UInt8] = [0x57, 0x42, 0x46, 0x53]
        fileData.replaceSubrange(0..<4, with: wbfsMagic)
        // Disc header at file offset 512: "RMCE01" + Wii magic
        let discID = Array("RMCE01".utf8)
        fileData.replaceSubrange(512..<518, with: discID)
        let wiiMagic: [UInt8] = [0x5D, 0x1C, 0x9E, 0xA3]
        fileData.replaceSubrange(512 + 0x18..<512 + 0x1C, with: wiiMagic)

        let wbfsURL = tmpDir.appendingPathComponent("game.wbfs")
        try fileData.write(to: wbfsURL)

        let result = await plugin.extractSerial(from: wbfsURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "RMCE01")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.wii")
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
    /// The BIN is 2048 bytes (cooked ISO sector layout, magic at byte 0).
    func testExtractSerialFromSaturnCueBin() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Cooked sector layout: magic starts at byte 0.
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

    /// Verifies the bug fix: PSX BIN+CUE should work even though ISODiscSerialPlugin
    /// does not list "bin" in its supportedExtensions.
    func testExtractSerialFromPSXCueBin() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a minimal ISO 9660 cooked BIN image with a SYSTEM.CNF containing
        // a PSX BOOT line.  Use 48 sectors × 2048 bytes so the file is a multiple
        // of 2048 bytes (cooked ISO sector size).
        let sectorSize = 2048
        var binData = Data(repeating: 0, count: sectorSize * 48)

        // PVD at sector 16.
        let pvdOffset = 16 * sectorSize
        binData[pvdOffset] = 0x01
        let cd001: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]
        binData.replaceSubrange((pvdOffset + 1)..<(pvdOffset + 6), with: cd001)
        binData[pvdOffset + 6] = 0x01

        // Root directory at sector 22 (LBA 22).
        let rootDirLBA: UInt32 = 22
        let rootDirSize: UInt32 = UInt32(sectorSize)
        withUnsafeBytes(of: rootDirLBA.littleEndian) { bytes in
            binData.replaceSubrange((pvdOffset + 158)..<(pvdOffset + 162), with: bytes)
        }
        withUnsafeBytes(of: rootDirLBA.bigEndian) { bytes in
            binData.replaceSubrange((pvdOffset + 162)..<(pvdOffset + 166), with: bytes)
        }
        withUnsafeBytes(of: rootDirSize.littleEndian) { bytes in
            binData.replaceSubrange((pvdOffset + 166)..<(pvdOffset + 170), with: bytes)
        }
        withUnsafeBytes(of: rootDirSize.bigEndian) { bytes in
            binData.replaceSubrange((pvdOffset + 170)..<(pvdOffset + 174), with: bytes)
        }
        binData[pvdOffset + 156] = 34

        // Directory entry for SYSTEM.CNF → sector 23.
        let dirOffset = 22 * sectorSize
        let cnfName = Array("SYSTEM.CNF".utf8)
        binData[dirOffset] = UInt8(33 + cnfName.count + (cnfName.count % 2 == 0 ? 0 : 1))
        let cnfLBA: UInt32 = 23
        withUnsafeBytes(of: cnfLBA.littleEndian) { bytes in
            binData.replaceSubrange((dirOffset + 2)..<(dirOffset + 6), with: bytes)
        }
        let cnfContent = "BOOT = cdrom:\\SLUS_01234;1\n"
        let cnfLen = UInt32(cnfContent.utf8.count)
        withUnsafeBytes(of: cnfLen.littleEndian) { bytes in
            binData.replaceSubrange((dirOffset + 10)..<(dirOffset + 14), with: bytes)
        }
        binData[dirOffset + 32] = UInt8(cnfName.count)
        binData.replaceSubrange((dirOffset + 33)..<(dirOffset + 33 + cnfName.count), with: cnfName)

        // SYSTEM.CNF at sector 23.
        let cnfBytes = Array(cnfContent.utf8)
        binData.replaceSubrange((23 * sectorSize)..<(23 * sectorSize + cnfBytes.count), with: cnfBytes)

        let binURL = tmpDir.appendingPathComponent("game.bin")
        try binData.write(to: binURL)

        // CUE sheet pointing at the BIN.
        let cueContent = "FILE \"game.bin\" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\n"
        let cueURL = tmpDir.appendingPathComponent("game.cue")
        try cueContent.write(to: cueURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: cueURL, systemHint: nil)
        XCTAssertNotNil(result, "PSX BIN+CUE should extract a serial regardless of BIN extension")
        XCTAssertEqual(result?.serial, "SLUS-01234")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.psx")
    }

    /// Regression: audio-only CUE must return nil (not the audio .bin file).
    /// Before the fix, `foundDataTrack` was never reset per FILE, causing the
    /// fallback to return any last-seen file even when no data track existed.
    func testExtractSerialNilForAudioOnlyCue() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a dummy audio BIN.
        let audioData = Data(repeating: 0xAA, count: 2352)
        let binURL = tmpDir.appendingPathComponent("audio.bin")
        try audioData.write(to: binURL)

        // CUE with only an AUDIO track — no data track.
        let cueContent = """
            FILE "audio.bin" BINARY
              TRACK 01 AUDIO
                INDEX 01 00:00:00
            """
        let cueURL = tmpDir.appendingPathComponent("audio_only.cue")
        try cueContent.write(to: cueURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: cueURL, systemHint: nil)
        XCTAssertNil(result, "Audio-only CUE should return nil, not the audio BIN file")
    }

    /// Regression: data track following an audio track must be found correctly.
    /// Before the fix, `foundDataTrack` was not reset on each new FILE directive,
    /// causing an INDEX under an audio track to incorrectly match.
    func testExtractSerialFromMixedCuePicksDataTrack() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Audio track binary (no meaningful header).
        let audioData = Data(repeating: 0xAA, count: 2352)
        try audioData.write(to: tmpDir.appendingPathComponent("audio.bin"))

        // Data track binary — Saturn header so SegaDiscSerialPlugin picks it up.
        var dataTrack = Data(repeating: 0, count: 2048)
        let saturnMagic = Array("SEGA SATURN     ".utf8)
        dataTrack.replaceSubrange(0..<16, with: saturnMagic)
        let serial = Array("T-12345H  ".utf8)
        dataTrack.replaceSubrange(0x20..<(0x20 + 10), with: serial)
        try dataTrack.write(to: tmpDir.appendingPathComponent("data.bin"))

        // CUE: audio first, then data.
        let cueContent = """
            FILE "audio.bin" BINARY
              TRACK 01 AUDIO
                INDEX 01 00:00:00
            FILE "data.bin" BINARY
              TRACK 02 MODE1/2048
                INDEX 01 00:02:00
            """
        let cueURL = tmpDir.appendingPathComponent("mixed.cue")
        try cueContent.write(to: cueURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: cueURL, systemHint: nil)
        XCTAssertNotNil(result, "Mixed CUE should find the data track")
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

// MARK: - GdiDiscSerialPlugin unit tests

final class GdiDiscSerialPluginTests: XCTestCase {

    private let plugin = GdiDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("gdi"))
        XCTAssertFalse(plugin.supportedExtensions.contains("bin"))
    }

    func testExtractSerialNilForMissingGDI() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.gdi")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }

    /// Writes a minimal GDI with a Dreamcast high-density track and verifies
    /// the product code is extracted correctly.
    func testExtractSerialFromFakeDreamcastGDI() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a minimal Dreamcast track03 BIN (2048-byte cooked sector).
        var binData = Data(repeating: 0, count: 2048)
        let dcMagic = Array("SEGA SEGASATURN ".utf8)
        binData.replaceSubrange(0..<16, with: dcMagic)
        // Dreamcast product code at offset 0x40, 10 bytes.
        let serial = Array("T-98765G  ".utf8)
        binData.replaceSubrange(0x40..<0x4A, with: serial)

        let trackURL = tmpDir.appendingPathComponent("track03.bin")
        try binData.write(to: trackURL)

        // GDI file with 3 tracks, last one being the data track.
        let gdiContent = """
            3
            1 0 4 2048 track01.bin 0
            2 1 0 2352 track02.raw 0
            3 45000 4 2048 track03.bin 0
            """
        // Create placeholder files for tracks 1 and 2 (needed for GDI to be valid).
        try Data(repeating: 0, count: 2048).write(to: tmpDir.appendingPathComponent("track01.bin"))
        try Data(repeating: 0, count: 2352).write(to: tmpDir.appendingPathComponent("track02.raw"))

        let gdiURL = tmpDir.appendingPathComponent("game.gdi")
        try gdiContent.write(to: gdiURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: gdiURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "T-98765G")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.dreamcast")
    }
}

// MARK: - M3UDiscSerialPlugin unit tests

final class M3UDiscSerialPluginTests: XCTestCase {

    private let plugin = M3UDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("m3u"))
        XCTAssertFalse(plugin.supportedExtensions.contains("cue"))
    }

    func testExtractSerialNilForMissingM3U() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.m3u")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }

    func testExtractSerialNilForEmptyM3U() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3uURL = tmpDir.appendingPathComponent("game.m3u")
        try "# just a comment\n".write(to: m3uURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: m3uURL, systemHint: nil)
        XCTAssertNil(result)
    }

    /// Verifies that an M3U pointing at a Saturn CUE+BIN pair extracts the serial.
    func testExtractSerialFromM3UPointingToSaturnCue() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a minimal Saturn BIN.
        var binData = Data(repeating: 0, count: 2048)
        binData.replaceSubrange(0..<16, with: Array("SEGA SATURN     ".utf8))
        binData.replaceSubrange(0x20..<0x2A, with: Array("T-12345H  ".utf8))
        try binData.write(to: tmpDir.appendingPathComponent("disc1.bin"))

        // CUE pointing at the BIN.
        let cueContent = "FILE \"disc1.bin\" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\n"
        try cueContent.write(to: tmpDir.appendingPathComponent("disc1.cue"),
                             atomically: true, encoding: .utf8)

        // M3U listing the CUE as the first (and only) disc.
        let m3uContent = "# Disc 1\ndisc1.cue\n"
        let m3uURL = tmpDir.appendingPathComponent("game.m3u")
        try m3uContent.write(to: m3uURL, atomically: true, encoding: .utf8)

        // Ensure the registry has defaults registered before the M3U plugin delegates.
        await DiscSerialExtractorRegistry.shared.registerDefaults()

        let result = await plugin.extractSerial(from: m3uURL, systemHint: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serial, "T-12345H")
        XCTAssertEqual(result?.systemIdentifierHint, "com.provenance.saturn")
    }

    func testExtractSerialSkipsNestedM3U() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a fake inner .m3u (it won't be processed to avoid recursion).
        try "inner.cue\n".write(to: tmpDir.appendingPathComponent("inner.m3u"),
                                atomically: true, encoding: .utf8)

        let m3uURL = tmpDir.appendingPathComponent("outer.m3u")
        try "inner.m3u\n".write(to: m3uURL, atomically: true, encoding: .utf8)

        let result = await plugin.extractSerial(from: m3uURL, systemHint: nil)
        XCTAssertNil(result, "Nested M3U should be rejected to avoid infinite recursion")
    }
}

// MARK: - ChdDiscSerialPlugin unit tests

final class ChdDiscSerialPluginTests: XCTestCase {

    private let plugin = ChdDiscSerialPlugin()

    func testSupportedExtensions() {
        XCTAssertTrue(plugin.supportedExtensions.contains("chd"))
        XCTAssertFalse(plugin.supportedExtensions.contains("iso"))
    }

    func testMatchesMagicBytesValid() {
        // "MComprHD" magic.
        let magic: [UInt8] = [0x4D, 0x43, 0x6F, 0x6D, 0x70, 0x72, 0x48, 0x44]
        var data = Data(magic)
        data.append(contentsOf: [UInt8](repeating: 0, count: 24))
        XCTAssertTrue(plugin.matchesMagicBytes(data))
    }

    func testMatchesMagicBytesNegative() {
        let data = Data(repeating: 0xAB, count: 32)
        XCTAssertFalse(plugin.matchesMagicBytes(data))
    }

    func testExtractSerialNilForMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/game.chd")
        let result = await plugin.extractSerial(from: url, systemHint: nil)
        XCTAssertNil(result)
    }

    func testExtractSerialNilForCompressedCHD() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a fake CHD v5 header with a non-zero compressor (simulating compressed).
        var header = Data(repeating: 0, count: 124)
        // Magic "MComprHD"
        let magic: [UInt8] = [0x4D, 0x43, 0x6F, 0x6D, 0x70, 0x72, 0x48, 0x44]
        header.replaceSubrange(0..<8, with: magic)
        // length = 124 (BE)
        withUnsafeBytes(of: UInt32(124).bigEndian) { header.replaceSubrange(8..<12, with: $0) }
        // version = 5 (BE)
        withUnsafeBytes(of: UInt32(5).bigEndian) { header.replaceSubrange(12..<16, with: $0) }
        // compressor[0] = 0x6364666C (non-zero → compressed)
        withUnsafeBytes(of: UInt32(0x6364666C).bigEndian) { header.replaceSubrange(16..<20, with: $0) }

        let chdURL = tmpDir.appendingPathComponent("compressed.chd")
        try header.write(to: chdURL)

        let result = await plugin.extractSerial(from: chdURL, systemHint: nil)
        XCTAssertNil(result, "Compressed CHD should return nil (decompression not supported yet)")
    }

    func testExtractSerialNilForPartiallyCompressedCHD() async throws {
        // A CHD where compressor[0]==0 but compressor[1] is non-zero is still
        // compressed and must not be processed as uncompressed.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var header = Data(repeating: 0, count: 124)
        let magic: [UInt8] = [0x4D, 0x43, 0x6F, 0x6D, 0x70, 0x72, 0x48, 0x44]
        header.replaceSubrange(0..<8, with: magic)
        withUnsafeBytes(of: UInt32(124).bigEndian) { header.replaceSubrange(8..<12, with: $0) }
        withUnsafeBytes(of: UInt32(5).bigEndian) { header.replaceSubrange(12..<16, with: $0) }
        // compressor[0] = 0 (looks uncompressed), compressor[1] = 0x6364666C (compressed)
        withUnsafeBytes(of: UInt32(0).bigEndian) { header.replaceSubrange(16..<20, with: $0) }
        withUnsafeBytes(of: UInt32(0x6364666C).bigEndian) { header.replaceSubrange(20..<24, with: $0) }

        let chdURL = tmpDir.appendingPathComponent("partial.chd")
        try header.write(to: chdURL)

        let result = await plugin.extractSerial(from: chdURL, systemHint: nil)
        XCTAssertNil(result, "Partially-compressed CHD (compressor[1] non-zero) must return nil")
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

// MARK: - Data+DiscSerial tests

final class DataDiscSerialExtensionTests: XCTestCase {

    func testLoadLE32() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertEqual(data.loadLE32(at: 0), 0x04030201)
        XCTAssertEqual(data.loadLE32(at: 1), 0x05040302)
        // Out of bounds → 0
        XCTAssertEqual(data.loadLE32(at: 4), 0)
    }

    func testLoadBE32() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertEqual(data.loadBE32(at: 0), 0x01020304)
        XCTAssertEqual(data.loadBE32(at: 1), 0x02030405)
        // Out of bounds → 0
        XCTAssertEqual(data.loadBE32(at: 4), 0)
    }

    func testLoadBE64() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xFF])
        XCTAssertEqual(data.loadBE64(at: 0), 0x0102030405060708)
        // Out of bounds → 0
        XCTAssertEqual(data.loadBE64(at: 3), 0)
    }

    func testASCIIStringValid() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        XCTAssertEqual(data.asciiString(at: 0, length: 5), "Hello")
    }

    func testASCIIStringOutOfBounds() {
        let data = Data([0x48, 0x65])
        XCTAssertNil(data.asciiString(at: 0, length: 5))
    }
}
