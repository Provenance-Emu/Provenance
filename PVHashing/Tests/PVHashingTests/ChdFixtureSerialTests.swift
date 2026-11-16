//
//  ChdFixtureSerialTests.swift
//  PVHashing
//
//  Reads serials out of real CHD files built by chdman (Resources/CHD/make_fixtures.py).
//  Every fixture is the same disc, whose SYSTEM.CNF names SLUS_123.45.
//

import XCTest
@testable import PVHashing

final class ChdFixtureSerialTests: XCTestCase {

    #if canImport(Compression)
    private static let hasDeflate = true
    #else
    private static let hasDeflate = false
    #endif

    private func serial(of name: String) async throws -> String? {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "chd", subdirectory: "CHD"),
                                "missing fixture \(name).chd")
        return await ChdDiscSerialPlugin().extractSerial(from: url, systemHint: nil)?.serial
    }

    private func assertReadsSerial(_ name: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let serial = try await serial(of: name)
        XCTAssertEqual(serial, "SLUS-12345", "\(name).chd", file: file, line: line)
    }

    // MARK: Stored uncompressed

    func testUncompressedCookedCD() async throws { try await assertReadsSerial("cd-mode1-none") }
    func testUncompressedRawMode2CD() async throws { try await assertReadsSerial("cd-mode2raw-none") }
    func testUncompressedDVD() async throws { try await assertReadsSerial("dvd-none") }

    // MARK: Compressed

    func testZlibCD() async throws {
        try XCTSkipUnless(Self.hasDeflate, "no DEFLATE off Apple platforms")
        try await assertReadsSerial("cd-mode1-cdzl")
    }
    func testLzmaCD() async throws { try await assertReadsSerial("cd-mode1-cdlz") }
    func testLzmaRawMode2CD() async throws { try await assertReadsSerial("cd-mode2raw-cdlz") }
    func testLzmaDVD() async throws { try await assertReadsSerial("dvd-lzma") }
    func testZlibDVD() async throws {
        try XCTSkipUnless(Self.hasDeflate, "no DEFLATE off Apple platforms")
        try await assertReadsSerial("dvd-zlib")
    }

    // MARK: Whole image

    /// Every sector of every readable fixture, against the plain image it was built from.
    func testEverySectorMatchesTheSourceImage() throws {
        let sectorBytes = 2048
        let source = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "disc", withExtension: "iso",
                                                                      subdirectory: "CHD")))
        // Fixture, and where the user data starts inside each unit.
        let fixtures = [("cd-mode1-none", 0), ("cd-mode1-cdzl", 0), ("cd-mode1-cdlz", 0),
                        ("cd-mode2raw-none", 24), ("cd-mode2raw-cdlz", 24),
                        ("dvd-none", 0), ("dvd-lzma", 0), ("dvd-zlib", 0)]
        for (name, payloadOffset) in fixtures where Self.hasDeflate || !name.contains("z") {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "chd", subdirectory: "CHD"))
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let image = try XCTUnwrap(CHDImage(handle: handle), name)
            var decoded = Data()
            for sector in 0..<(source.count / sectorBytes) {
                let unit = try XCTUnwrap(image.unit(sector), "\(name) sector \(sector)")
                decoded.append(unit.subdata(in: payloadOffset..<(payloadOffset + sectorBytes)))
            }
            XCTAssertEqual(decoded, source, name)
        }
    }

    // MARK: Damaged files

    /// A CHD comes from the user, so a damaged one must fail quietly. Each round overwrites
    /// a few bytes of a compressed fixture and reads every sector; the test passes by not crashing.
    func testDamagedFilesDoNotCrash() throws {
        var generator = SplitMix(seed: 3400)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("chd-damage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["cd-mode1-cdlz", "cd-mode1-cdzl", "dvd-lzma", "dvd-zlib", "cd-mode1-none"] {
            let original = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "chd",
                                                                           subdirectory: "CHD")))
            for round in 0..<40 {
                var damaged = original
                for _ in 0..<(1 + round % 6) {
                    damaged[Int(generator.next() % UInt64(damaged.count))] = UInt8(truncatingIfNeeded: generator.next())
                }
                let url = directory.appendingPathComponent("\(name)-\(round).chd")
                try damaged.write(to: url)
                let handle = try FileHandle(forReadingFrom: url)
                if let image = CHDImage(handle: handle) {
                    let units = min(image.hunkCount * (image.hunkBytes / image.unitBytes), 128)
                    for unit in 0..<units { _ = image.unit(unit) }
                }
                try handle.close()
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    /// A small fixed-seed generator, so a failure repeats.
    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    // MARK: Not read

    /// zstd has no decoder here, so these discs fall back to the importer's MD5 match.
    func testZstdIsNotRead() async throws {
        let cd = try await serial(of: "cd-mode1-cdzs")
        let dvd = try await serial(of: "dvd-zstd")
        XCTAssertNil(cd)
        XCTAssertNil(dvd)
    }
}
