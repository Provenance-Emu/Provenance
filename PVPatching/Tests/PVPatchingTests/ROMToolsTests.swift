//
//  ROMToolsTests.swift
//  PVPatchingTests
//

import Foundation
import XCTest
@testable import PVPatching

final class ROMToolsTests: XCTestCase {

    func testCRC32KnownVector() {
        // CRC-32/ISO-HDLC of "123456789" is 0xCBF43926.
        let data = Data("123456789".utf8)
        XCTAssertEqual(PatchCRCValidator.crc32(of: data), 0xCBF4_3926)
    }

    func testValidateMatchedAndMismatched() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROMToolsCRC-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let romURL = dir.appendingPathComponent("game.rom")
        let rom = Data((0..<32).map { UInt8($0) })
        try rom.write(to: romURL)
        let crc = PatchCRCValidator.crc32(of: rom)

        let matchedInspection = PatchInspection(
            format: .bps,
            title: "Match",
            sourceCRC32: crc,
            targetCRC32: 1,
            patchSHA256: "abc"
        )
        XCTAssertEqual(
            try PatchCRCValidator.validate(romURL: romURL, inspection: matchedInspection),
            .matched(expected: crc, actual: crc)
        )

        let mismatchedInspection = PatchInspection(
            format: .bps,
            title: "Mismatch",
            sourceCRC32: crc &+ 1,
            targetCRC32: 1,
            patchSHA256: "abc"
        )
        let mismatch = try PatchCRCValidator.validate(romURL: romURL, inspection: mismatchedInspection)
        XCTAssertTrue(mismatch.isMismatch)
        XCTAssertTrue(mismatch.userMessage.contains("Warning"))
    }

    func testValidateUnavailableWithoutSourceCRC() throws {
        let inspection = PatchInspection(
            format: .ips,
            title: "IPS",
            sourceCRC32: nil,
            patchSHA256: "abc"
        )
        XCTAssertEqual(
            PatchCRCValidator.validate(romCRC: 0x1234, inspection: inspection),
            .unavailable
        )
    }

    func testApplyPatchToolOperationExports() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROMToolsApply-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = Data((0..<64).map { UInt8($0) })
        var modified = original
        modified[4] = 0xFF

        let romURL = dir.appendingPathComponent("base.rom")
        let modifiedURL = dir.appendingPathComponent("hack.rom")
        let patchURL = dir.appendingPathComponent("hack.bps")
        let outDir = dir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try original.write(to: romURL)
        try modified.write(to: modifiedURL)

        _ = try PatchCreator().create(
            originalURL: romURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .bps,
            metadata: PatchMetadata(title: "Tool Op")
        )

        let tool = ApplyPatchToolOperation()
        let outputs = try await tool.execute(
            inputs: [patchURL, romURL],
            outputDirectory: outDir,
            progress: nil
        )
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(try Data(contentsOf: outputs[0]), modified)
        XCTAssertNotNil(ROMToolRegistry.default.operation(id: "apply-patch"))
    }

    func testBatchPlanAndApply() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROMToolsBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = Data((0..<48).map { UInt8($0) })
        var modified = original
        modified[2] = 0xAA

        let romURL = dir.appendingPathComponent("Adventure.rom")
        let modifiedURL = dir.appendingPathComponent("Adventure-hack.rom")
        let patchURL = dir.appendingPathComponent("Adventure.bps")
        let outDir = dir.appendingPathComponent("PatchedROMs", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try original.write(to: romURL)
        try modified.write(to: modifiedURL)

        _ = try PatchCreator().create(
            originalURL: romURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .bps,
            metadata: PatchMetadata(title: "Adventure")
        )

        let crc = PatchCRCValidator.crc32(of: original)
        let batcher = BatchPatchApplier()
        let roms = [
            BatchPatchApplier.ROMCandidate(
                id: "md5-adventure",
                title: "Adventure",
                filename: "Adventure.rom",
                fileURL: romURL,
                crc32: crc
            )
        ]
        let plan = await batcher.plan(patchURLs: [patchURL], roms: roms)
        let jobs = plan.jobs
        XCTAssertEqual(jobs.count, 1)
        XCTAssertTrue(plan.failed.isEmpty)
        XCTAssertTrue(plan.unmatched.isEmpty)
        XCTAssertFalse(jobs[0].crcValidation.isMismatch)

        let results = await batcher.apply(jobs: jobs, outputDirectory: outDir, allowCRCMismatch: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(results[0].outputURL)), modified)
    }

    func testBatchPlanSkipsUnreadablePatchAndKeepsOthers() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROMToolsBatchSkip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = Data((0..<48).map { UInt8($0) })
        var modified = original
        modified[1] = 0x5A
        let romURL = dir.appendingPathComponent("Pitfall.rom")
        let modifiedURL = dir.appendingPathComponent("Pitfall-hack.rom")
        let goodPatch = dir.appendingPathComponent("Pitfall.bps")
        let badPatch = dir.appendingPathComponent("Broken.bps")
        try original.write(to: romURL)
        try modified.write(to: modifiedURL)
        try Data().write(to: badPatch)
        _ = try PatchCreator().create(
            originalURL: romURL,
            modifiedURL: modifiedURL,
            outputURL: goodPatch,
            format: .bps,
            metadata: PatchMetadata(title: "Pitfall")
        )

        let batcher = BatchPatchApplier()
        let roms = [
            BatchPatchApplier.ROMCandidate(
                id: "md5-pitfall", title: "Pitfall", filename: "Pitfall.rom", fileURL: romURL, crc32: nil
            )
        ]
        // CRC is only requested for name-matched ROMs lacking one.
        let plan = await batcher.plan(patchURLs: [badPatch, goodPatch], roms: roms) { rom in
            try? PatchCRCValidator.crc32(ofFileAt: rom.fileURL)
        }
        XCTAssertEqual(plan.failed.map(\.patchURL.lastPathComponent), ["Broken.bps"])
        XCTAssertEqual(plan.jobs.map(\.patchURL.lastPathComponent), ["Pitfall.bps"])
        XCTAssertEqual(plan.jobs.first?.confidence, .exact)
        XCTAssertFalse(plan.jobs[0].crcValidation.isMismatch)
    }

    func testPatchFormatMagicSniffing() {
        XCTAssertEqual(PatchFormat.detect(fromMagic: Data("PATCH\u{0}".utf8)), .ips)
        XCTAssertEqual(PatchFormat.detect(fromMagic: Data("BPS1\u{0}".utf8)), .bps)
        XCTAssertEqual(PatchFormat.detect(fromMagic: Data("UPS1\u{0}".utf8)), .ups)
        XCTAssertEqual(PatchFormat.detect(fromMagic: Data("PPF30".utf8)), .ppf)
        XCTAssertNil(PatchFormat.detect(fromMagic: Data([0x50, 0x4B, 0x03, 0x04, 0x14])))
        XCTAssertTrue(PatchFormat.implementedFileExtensions.isSuperset(of: ["ips", "bps", "ups", "ppf"]))
        XCTAssertFalse(PatchFormat.implementedFileExtensions.contains("xdelta"))
    }

    func testBatchSkipsCRCMismatchUnlessAllowed() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROMToolsBatchCRC-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let job = BatchPatchJob(
            patchURL: dir.appendingPathComponent("x.bps"),
            romURL: dir.appendingPathComponent("y.rom"),
            romTitle: "Y",
            confidence: .high,
            crcValidation: .mismatched(expected: 1, actual: 2)
        )
        let batcher = BatchPatchApplier()
        let blocked = await batcher.apply(jobs: [job], outputDirectory: dir, allowCRCMismatch: false)
        XCTAssertEqual(blocked.count, 1)
        XCTAssertFalse(blocked[0].success)
        XCTAssertTrue(blocked[0].message.contains("Warning"))
    }
}

final class VariableLengthIntegerTests: XCTestCase {
    /// Regression: the decoder used `|=` where the BPS/UPS spec adds, so any value
    /// whose implicit carry bit collided with the next group decoded wrong
    /// (`[0x00, 0x81]` came back as 128 instead of 256).
    func testRoundTripAcrossGroupBoundaries() {
        let values = [0, 1, 127, 128, 129, 255, 256, 257, 16_383, 16_384, 16_511, 16_512,
                      1 << 20, (1 << 21) - 1, 1 << 24, 0x1234_5678, 1 << 32, (1 << 40) + 3]
        for value in values {
            let bytes = Data(encodeVLI(value))
            var pos = 0
            XCTAssertEqual(readVLI(bytes, pos: &pos), value, "VLI \(value) did not round-trip")
            XCTAssertEqual(pos, bytes.count)
        }
    }

    func testKnownEncodings() {
        var pos = 0
        XCTAssertEqual(readVLI(Data([0x00, 0x81]), pos: &pos), 256)
        pos = 0
        XCTAssertEqual(readVLI(Data([0x03, 0x81]), pos: &pos), 259)
        pos = 0
        XCTAssertEqual(readVLI(Data([0xFF]), pos: &pos), 127)
    }

    func testUnterminatedAndOversizedEncodingsFailLoudly() {
        var pos = 0
        XCTAssertEqual(readVLI(Data([0x00, 0x00, 0x00]), pos: &pos), Int.max)
        pos = 0
        XCTAssertEqual(readVLI(Data(repeating: 0x7F, count: 12), pos: &pos), Int.max)
    }
}
