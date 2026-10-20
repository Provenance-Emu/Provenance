//
//  PatchCreatorTests.swift
//  PVPatchingTests
//

import Foundation
import XCTest
import Testing
@testable import PVPatching

final class PatchCreatorTests: XCTestCase {
    func testCreateAndApplyBPSRoundTrip() async throws {
        let original = Data((0..<256).map { UInt8($0) })
        var modified = original
        modified[10] = 0xAA
        modified[11] = 0xBB
        modified.append(contentsOf: [0x01, 0x02, 0x03])

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchCreatorBPS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalURL = dir.appendingPathComponent("game.rom")
        let modifiedURL = dir.appendingPathComponent("game-hack.rom")
        let patchURL = dir.appendingPathComponent("game.bps")
        try original.write(to: originalURL)
        try modified.write(to: modifiedURL)

        _ = try await PatchCreator().create(
            originalURL: originalURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .bps,
            metadata: PatchMetadata(title: "Test Hack", author: "Provenance")
        )

        let inspection = try PatchInspector().inspect(patchURL: patchURL)
        XCTAssertEqual(inspection.format, .bps)
        XCTAssertEqual(inspection.title, "Test Hack")
        XCTAssertEqual(inspection.author, "Provenance")
        XCTAssertEqual(inspection.sourceCRC32, crc32(original))
        XCTAssertEqual(inspection.targetCRC32, crc32(modified))

        let applied = try await BPSPatcher().apply(patch: Data(contentsOf: patchURL), to: original)
        XCTAssertEqual(applied, modified)
    }

    func testCreateBPSWhenModifiedIsShorterThanOriginal() async throws {
        let original = Data((0..<64).map { UInt8($0) })
        let modified = Data(original.prefix(40)) // shrink

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchCreatorBPSShrink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalURL = dir.appendingPathComponent("long.rom")
        let modifiedURL = dir.appendingPathComponent("short.rom")
        let patchURL = dir.appendingPathComponent("shrink.bps")
        try original.write(to: originalURL)
        try modified.write(to: modifiedURL)

        _ = try await PatchCreator().create(
            originalURL: originalURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .bps
        )

        let applied = try await BPSPatcher().apply(patch: Data(contentsOf: patchURL), to: original)
        XCTAssertEqual(applied, modified)
    }

    func testCreateAndApplyIPSRoundTrip() async throws {
        let original = Data(repeating: 0x00, count: 64)
        var modified = original
        modified[5] = 0x11
        modified[6] = 0x22
        modified[20] = 0x33

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchCreatorIPS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalURL = dir.appendingPathComponent("cart.bin")
        let modifiedURL = dir.appendingPathComponent("cart-mod.bin")
        let patchURL = dir.appendingPathComponent("cart.ips")
        try original.write(to: originalURL)
        try modified.write(to: modifiedURL)

        _ = try await PatchCreator().create(
            originalURL: originalURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .ips
        )

        let applied = try await IPSPatcher().apply(patch: Data(contentsOf: patchURL), to: original)
        XCTAssertEqual(applied, modified)
    }

    func testApplierReturnsUniqueStemAndCaches() async throws {
        let original = Data((0..<128).map { UInt8($0) })
        var modified = original
        modified[0] = 0xFF

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchApplierCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let romURL = dir.appendingPathComponent("Zelda.nes")
        let modURL = dir.appendingPathComponent("Zelda-mod.nes")
        let patchURL = dir.appendingPathComponent("Zelda Translation.bps")
        try original.write(to: romURL)
        try modified.write(to: modURL)
        _ = try await PatchCreator().create(
            originalURL: romURL,
            modifiedURL: modURL,
            outputURL: patchURL,
            format: .bps
        )

        let cacheDir = dir.appendingPathComponent("cache", isDirectory: true)
        let applier = PatchApplier(cache: PatchCache(cacheDirectory: cacheDir))
        let first = try await applier.apply(patchURL: patchURL, to: romURL)
        XCTAssertFalse(first.wasCached)
        XCTAssertTrue(first.url.lastPathComponent.contains("Zelda"))
        XCTAssertNotEqual(first.url.deletingPathExtension().lastPathComponent, "patched")

        let second = try await applier.apply(patchURL: patchURL, to: romURL)
        XCTAssertTrue(second.wasCached)
        XCTAssertEqual(first.url, second.url)
        XCTAssertEqual(first.patchedMD5, second.patchedMD5)
    }

    func testCreateAndApplyIPS32RoundTrip() async throws {
        // Force an offset that requires 32-bit IPS encoding (> 0xFFFFFF).
        var original = Data(repeating: 0x00, count: 0x1000000 + 16)
        var modified = original
        modified[0x1000000] = 0x7F
        modified[0x1000001] = 0x80

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchCreatorIPS32-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalURL = dir.appendingPathComponent("big.bin")
        let modifiedURL = dir.appendingPathComponent("big-mod.bin")
        let patchURL = dir.appendingPathComponent("big.ips32")
        try original.write(to: originalURL)
        try modified.write(to: modifiedURL)

        _ = try await PatchCreator().create(
            originalURL: originalURL,
            modifiedURL: modifiedURL,
            outputURL: patchURL,
            format: .ips32
        )

        let applied = try await IPSPatcher().apply(
            patch: Data(contentsOf: patchURL),
            to: original,
            isIPS32: true
        )
        XCTAssertEqual(applied, modified)
    }

    func testInspectorRanksExactCRCMatchHighest() async throws {
        let original = Data([1, 2, 3, 4, 5, 6, 7, 8])
        var modified = original
        modified[2] = 9
        let patch = try await PatchCreator().createBPSForTests(original: original, modified: modified)

        let inspection = try PatchInspector().inspect(patchData: patch, format: .bps, fallbackTitle: "Hack")
        let candidates = [
            PatchMatchCandidate(id: "a", title: "Wrong", md5: "A", crc32: 0x11111111, filename: "wrong.rom", confidence: .none, score: 0),
            PatchMatchCandidate(id: "b", title: "Right", md5: "B", crc32: inspection.sourceCRC32, filename: "right.rom", confidence: .none, score: 0)
        ]
        let ranked = PatchInspector().rank(candidates: candidates, inspection: inspection, patchFilename: "Hack.bps")
        XCTAssertEqual(ranked.first?.id, "b")
        XCTAssertEqual(ranked.first?.confidence, .exact)
        XCTAssertNotNil(PatchInspector().unambiguousMatch(from: ranked))
    }
}

struct PatchCreatorInputProtectionTests {
    @Test(arguments: PatchCreator.CreationFormat.allCases, ["original", "modified", "symlink", "hardlink"])
    func rejectsOutputAliasingAnInput(format: PatchCreator.CreationFormat, destination: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data([1, 2, 3, 4])
        let modified = Data([1, 9, 3, 4])
        let originalURL = directory.appendingPathComponent("original.rom")
        let modifiedURL = directory.appendingPathComponent("modified.rom")
        try original.write(to: originalURL)
        try modified.write(to: modifiedURL)
        let outputURL: URL
        switch destination {
        case "original": outputURL = originalURL
        case "modified": outputURL = modifiedURL
        case "symlink":
            outputURL = directory.appendingPathComponent("alias.patch")
            try FileManager.default.createSymbolicLink(at: outputURL, withDestinationURL: originalURL)
        default:
            outputURL = directory.appendingPathComponent("alias.patch")
            try FileManager.default.linkItem(at: modifiedURL, to: outputURL)
        }

        await #expect(throws: PatchError.self) {
            try await PatchCreator().create(
                originalURL: originalURL, modifiedURL: modifiedURL, outputURL: outputURL, format: format
            )
        }
        #expect(try Data(contentsOf: originalURL) == original)
        #expect(try Data(contentsOf: modifiedURL) == modified)
    }
}

private extension PatchCreator {
    func createBPSForTests(original: Data, modified: Data) async throws -> Data {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bps-inline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let o = dir.appendingPathComponent("o.bin")
        let m = dir.appendingPathComponent("m.bin")
        let p = dir.appendingPathComponent("p.bps")
        try original.write(to: o)
        try modified.write(to: m)
        _ = try await create(originalURL: o, modifiedURL: m, outputURL: p, format: .bps)
        return try Data(contentsOf: p)
    }
}
