//
//  PatchCacheFastPathTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class PatchCacheFastPathTests: XCTestCase {
    private var dir: URL!
    private var romURL: URL!
    private var patchURL: URL!
    private var applier: PatchApplier!
    private var original = Data()
    private var modified = Data()

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FastPath-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        original = Data((0..<512).map { UInt8($0 & 0xFF) })
        modified = original
        modified[300] = 0xEE
        romURL = dir.appendingPathComponent("Game.sfc")
        let modifiedURL = dir.appendingPathComponent("Game-hack.sfc")
        patchURL = dir.appendingPathComponent("Game-hack.bps")
        try original.write(to: romURL)
        try modified.write(to: modifiedURL)
        _ = try await PatchCreator().create(
            originalURL: romURL, modifiedURL: modifiedURL, outputURL: patchURL,
            format: .bps, metadata: PatchMetadata(title: "fast")
        )
        applier = PatchApplier(cache: PatchCache(cacheDirectory: dir.appendingPathComponent("cache", isDirectory: true)))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSecondApplyHitsTheFingerprintSidecarWithoutRehashing() async throws {
        let first = try await applier.apply(patchURL: patchURL, to: romURL)
        XCTAssertFalse(first.wasCached)
        XCTAssertEqual(try Data(contentsOf: first.url), modified)

        let sidecars = dir.appendingPathComponent("cache/.fingerprints", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: sidecars.path)
        XCTAssertEqual(files.count, 1)

        let second = try await applier.apply(patchURL: patchURL, to: romURL)
        XCTAssertTrue(second.wasCached)
        XCTAssertEqual(second.url, first.url)
        XCTAssertEqual(second.patchedMD5, first.patchedMD5)
        XCTAssertEqual(second.patchedSHA256, first.patchedSHA256)
    }

    func testChangedROMBytesInvalidateTheFastPath() async throws {
        _ = try await applier.apply(patchURL: patchURL, to: romURL)

        // Same size, different bytes, newer mtime — a different dump of the "same" ROM.
        var other = original
        other[10] ^= 0xFF
        try other.write(to: romURL)
        let future = Date().addingTimeInterval(5)
        try FileManager.default.setAttributes([.modificationDate: future], ofItemAtPath: romURL.path)

        do {
            _ = try await applier.apply(patchURL: patchURL, to: romURL)
            XCTFail("expected the BPS source CRC check to reject the changed ROM")
        } catch PatchError.sourceROMMismatch {
            // expected: fast path missed, slow path verified the real bytes
        }
    }

    func testMissingOutputFallsBackToSlowPath() async throws {
        let first = try await applier.apply(patchURL: patchURL, to: romURL)
        try FileManager.default.removeItem(at: first.url)
        let again = try await applier.apply(patchURL: patchURL, to: romURL)
        XCTAssertFalse(again.wasCached)
        XCTAssertEqual(try Data(contentsOf: again.url), modified)
    }

    func testDifferentStemIsADifferentFingerprint() async throws {
        let a = try await applier.apply(patchURL: patchURL, to: romURL, outputStem: "A")
        let b = try await applier.apply(patchURL: patchURL, to: romURL, outputStem: "B")
        XCTAssertNotEqual(a.url, b.url)
        XCTAssertTrue(b.wasCached == false || b.url.lastPathComponent.hasPrefix("B"))
    }
}
