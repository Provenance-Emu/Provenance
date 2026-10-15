//
//  PatchInspectorAndCacheTests.swift
//  PVPatchingTests
//

import Foundation
import XCTest
@testable import PVPatching

final class PatchInspectorAndCacheTests: XCTestCase {

    func testExportIsCollisionSafe() async throws {
        let original = Data((0..<64).map { UInt8($0) })
        var modified = original
        modified[1] = 0xEE

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let romURL = dir.appendingPathComponent("game.bin")
        let modURL = dir.appendingPathComponent("game-mod.bin")
        let patchURL = dir.appendingPathComponent("game.bps")
        try original.write(to: romURL)
        try modified.write(to: modURL)
        _ = try await PatchCreator().create(
            originalURL: romURL,
            modifiedURL: modURL,
            outputURL: patchURL,
            format: .bps
        )

        let cacheDir = dir.appendingPathComponent("cache", isDirectory: true)
        let exportDir = dir.appendingPathComponent("out", isDirectory: true)
        let applier = PatchApplier(cache: PatchCache(cacheDirectory: cacheDir))

        let first = try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: exportDir,
            preferredName: "game [hack].bin"
        )
        // Seed a same-named different file to force collision handling.
        try Data([0x00]).write(to: first)

        let second = try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: exportDir,
            preferredName: "game [hack].bin"
        )
        XCTAssertNotEqual(first.lastPathComponent, second.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testUnambiguousMatchRequiresClearWinner() async throws {
        let inspection = PatchInspection(
            format: .ips,
            title: "Hack",
            patchSHA256: "abc"
        )
        let candidates = [
            PatchMatchCandidate(id: "1", title: "A", md5: "1", filename: "hack.rom", confidence: .none, score: 0),
            PatchMatchCandidate(id: "2", title: "B", md5: "2", filename: "hack.rom", confidence: .none, score: 0)
        ]
        let ranked = PatchInspector().rank(
            candidates: candidates,
            inspection: inspection,
            patchFilename: "Hack.ips"
        )
        // Two equally strong filename matches should not auto-link.
        XCTAssertNil(PatchInspector().unambiguousMatch(from: ranked))
    }

    func testIdenticalROMsFailCreation() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchSame-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let data = Data(repeating: 1, count: 32)
        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        let out = dir.appendingPathComponent("out.bps")
        try data.write(to: a)
        try data.write(to: b)

        await assertThrowsAsync(try await PatchCreator().create(originalURL: a, modifiedURL: b, outputURL: out, format: .bps)
        )
    }

    func testDefaultOutputStemIsHumanReadable() async {
        let rom = URL(fileURLWithPath: "/tmp/Zelda.nes")
        let patch = URL(fileURLWithPath: "/tmp/French Translation.bps")
        let stem = PatchApplier.defaultOutputStem(romURL: rom, patchURL: patch)
        XCTAssertTrue(stem.contains("Zelda"))
        XCTAssertTrue(stem.contains("French"))
        XCTAssertNotEqual(stem, "patched")
    }
}
