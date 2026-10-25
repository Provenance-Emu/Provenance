#!/usr/bin/env python3
"""Exercise the importer's production fallback with real same-name ROM bytes."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
importer = (root/'PVLibrary/Sources/PVLibrary/Importer/Services/GameImporter/GameImporter.swift').read_text()
start = importer.index('                /// Check cache for game keys, but query Realm for actual file access')
end = importer.index('            }\n\n            return false', start)
fallback = importer[start:end]
files = (root/'PVLibrary/Sources/PVLibrary/Importer/Services/GameImporter/GameImporterFileService.swift').read_text()
collision_start = files.index('        if FileManager.default.fileExists(atPath: expectedPath.path),\n           await !Self.filesAreByteIdentical')
collision = files[collision_start:files.index('        // If the file already exists at the destination, handle it specially', collision_start)]
helpers = files[files.index('    private static func filesAreByteIdentical'):files.index('    func removeImportItemFile', files.index('    private static func filesAreByteIdentical'))]
mover = '''
func calculateMD5Async(of url: URL) async throws -> String { try md5(url) }
enum GameImporterError: Error { case failedToMoveROM(Error) }
final class MovingItem {
    let url: URL
    var destinationUrl: URL?
    var childQueueItems: [URL] = []
    var resolvedAssociatedFileURLs: [URL] = []
    init(_ url: URL) { self.url = url }
}
final class FileService {
    func moveFile(_ from: URL, toExplicitDestination dest: URL) async throws -> URL {
        try FileManager.default.moveItem(at: from, to: dest)
        return dest
    }
    func moveStagedArchiveCompanions(forQueueItem: MovingItem) {}
    func moveChildImports(forQueueItem: MovingItem, to: URL) async throws {}
    func moveAssociatedFiles(forQueueItem: MovingItem, to: URL) async throws {}
    func move(_ queueItem: MovingItem, to destinationFolder: URL) async throws {
        let fileName = queueItem.url.lastPathComponent
        let expectedPath = destinationFolder.appendingPathComponent(fileName)
''' + collision + '}\n' + helpers + '}\n'
stubs = '''import Foundation
import CryptoKit
func ILOG(_ s: String) {}
func WLOG(_ s: String) {}
struct System { let rawValue: String }
struct File { var url: URL? }
final class PVGame {
    var id: String
    var systemIdentifier = "gc"
    var title: String? = "Existing"
    var file: File?
    init(url: URL) throws { id = try md5(url); file = File(url: url) }
}
func md5(_ url: URL) throws -> String { Insecure.MD5.hash(data: try Data(contentsOf: url)).map { String(format: "%02X", $0) }.joined() }
struct ImportQueueItem {
    let md5: String?
    var isMultiFileIndex = false
    var requiresContentBasedDuplicateCheck = false
}
struct RealmStub {
    let game: PVGame
    func object(ofType: PVGame.Type, forPrimaryKey key: String) -> PVGame? { key == game.id ? game : nil }
}
enum RealmContext {
    static var game: PVGame!
    static func withRealm<T>(_ body: (RealmStub) -> T) async throws -> T { body(RealmStub(game: game)) }
}
func isDuplicate(_ item: ImportQueueItem, existing: PVGame) async -> Bool {
    let partialPath = "gc/game.rvz", similarName = "gc/game"
    let gamesCache = [partialPath: existing]
    let system = System(rawValue: "gc")
'''
tests = '''import XCTest
@testable import DuplicateHarness
final class DuplicateAdmissionTests: XCTestCase {
    func check(incoming: String, verified: Bool, expected: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let local = root.appendingPathComponent("library/game.rvz")
        let remote = root.appendingPathComponent("incoming/game.rvz")
        try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("old game".utf8).write(to: local)
        try Data(incoming.utf8).write(to: remote)
        let game = try PVGame(url: local)
        RealmContext.game = game
        let item = ImportQueueItem(md5: try md5(remote), requiresContentBasedDuplicateCheck: verified)
        let duplicate = await isDuplicate(item, existing: game)
        XCTAssertEqual(duplicate, expected)
        if !duplicate, incoming != "old game" {
            let moved = MovingItem(remote)
            try await FileService().move(moved, to: local.deletingLastPathComponent())
            XCTAssertEqual(moved.destinationUrl?.lastPathComponent, "game_1.rvz")
            XCTAssertEqual(try Data(contentsOf: moved.destinationUrl!), Data(incoming.utf8))
            XCTAssertFalse(FileManager.default.fileExists(atPath: remote.path))
        } else {
            XCTAssertEqual(try Data(contentsOf: remote), Data(incoming.utf8))
        }
        XCTAssertEqual(try Data(contentsOf: local), Data("old game".utf8))
    }
    func testVerifiedDistinctSameNameIsAdmitted() async throws { try await check(incoming: "new game", verified: true, expected: false) }
    func testVerifiedIdenticalBytesRemainDuplicate() async throws { try await check(incoming: "old game", verified: true, expected: true) }
    func testOrdinaryImportRetainsExistingDuplicatePolicy() async throws { try await check(incoming: "new game", verified: false, expected: true) }
    func testMissingLocalFileDoesNotBlockRestoration() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("old game".utf8).write(to: url)
        let game = try PVGame(url: url)
        try FileManager.default.removeItem(at: url)
        RealmContext.game = game
        let item = ImportQueueItem(md5: game.id, requiresContentBasedDuplicateCheck: true)
        let duplicate = await isDuplicate(item, existing: game)
        XCTAssertFalse(duplicate)
    }
}
'''
with tempfile.TemporaryDirectory(prefix='provenance-nearby-duplicate-') as name:
    package = Path(name)
    (package/'Sources').mkdir(); (package/'Tests').mkdir()
    (package/'Sources/Duplicate.swift').write_text(stubs + fallback + '\n    return false\n}\n' + mover)
    (package/'Tests/DuplicateTests.swift').write_text(tests)
    (package/'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "DuplicateHarness", platforms: [.macOS(.v14)], targets: [
.target(name: "DuplicateHarness", path: "Sources"),
.testTarget(name: "DuplicateTests", dependencies: ["DuplicateHarness"], path: "Tests")])
''')
    raise SystemExit(subprocess.call(['swift', 'test', '--package-path', str(package), '--jobs', '4']))
