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
        let jobs = try await batcher.plan(patchURLs: [patchURL], roms: roms)
        XCTAssertEqual(jobs.count, 1)
        XCTAssertFalse(jobs[0].crcValidation.isMismatch)

        let results = await batcher.apply(jobs: jobs, outputDirectory: outDir, allowCRCMismatch: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertEqual(try Data(contentsOf: results[0].outputURL!), modified)
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
