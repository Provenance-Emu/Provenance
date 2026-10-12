//
//  PatchRepositoryFileTests.swift
//  PVLibraryTests
//
//  File-level behaviour of PatchRepository that needs no Realm rows.
//

import XCTest
import PVPatching
import PVFileSystem
@testable import PVLibrary

@MainActor
final class PatchRepositoryFileTests: XCTestCase {
    private var scratch: URL!
    private var created: [URL] = []

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchRepoFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
        for url in created { try? FileManager.default.removeItem(atPath: url.path) }
        created = []
    }

    /// Minimal valid IPS: header + EOF. Distinct payloads give distinct SHA-256s.
    private func writeIPS(named name: String, marker: UInt8) throws -> URL {
        var data = Data("PATCH".utf8)
        data.append(contentsOf: [0x00, 0x00, 0x10, 0x00, 0x01, marker]) // one 1-byte record @0x10
        data.append(contentsOf: Data("EOF".utf8))
        let url = scratch.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testSameNameDifferentBytesGetsAContentSuffix() throws {
        let unique = "PRFT-\(UUID().uuidString.prefix(8)).ips"
        let first = try writeIPS(named: unique, marker: 0x01)
        let dest1 = try PatchRepository.shared.copyIntoPatchesDirectory(first)
        created.append(dest1)
        XCTAssertEqual(dest1.lastPathComponent, unique)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest1.path))

        // Same filename, different content (a different hack that happens to share the name).
        let otherDir = scratch.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
        var data = try Data(contentsOf: first)
        data[data.count - 4] = 0x02 // flip the record byte
        let second = otherDir.appendingPathComponent(unique)
        try data.write(to: second)

        let dest2 = try PatchRepository.shared.copyIntoPatchesDirectory(second)
        created.append(dest2)
        XCTAssertNotEqual(dest2, dest1, "a different patch must not overwrite the existing file")
        XCTAssertEqual(dest2.pathExtension, "ips")
        XCTAssertTrue(dest2.lastPathComponent.hasPrefix(String(unique.dropLast(4)) + "-"))
        // The first file is untouched.
        XCTAssertEqual(try Data(contentsOf: dest1), try Data(contentsOf: first))
    }

    func testSameBytesReuseTheExistingFile() throws {
        let unique = "PRFT-\(UUID().uuidString.prefix(8)).ips"
        let first = try writeIPS(named: unique, marker: 0x07)
        let dest1 = try PatchRepository.shared.copyIntoPatchesDirectory(first)
        created.append(dest1)

        let otherDir = scratch.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
        let copy = otherDir.appendingPathComponent(unique)
        try FileManager.default.copyItem(at: first, to: copy)

        let dest2 = try PatchRepository.shared.copyIntoPatchesDirectory(copy)
        XCTAssertEqual(dest2, dest1, "identical bytes should map to the same library file")
    }

    func testFileAlreadyInPatchesDirectoryIsReturnedAsIs() throws {
        let dir = Paths.patchesPath
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("PRFT-inplace-\(UUID().uuidString.prefix(8)).ips")
        try Data("PATCH".utf8).write(to: url)
        created.append(url)
        XCTAssertEqual(try PatchRepository.shared.copyIntoPatchesDirectory(url), url)
    }
}
