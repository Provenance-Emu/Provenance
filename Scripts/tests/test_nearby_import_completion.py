#!/usr/bin/env python3
"""Native tests of the actual app completion bridge and importer duplicate guard.
No app/core build: model stand-ins expose only the production APIs these helpers use.
"""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
service = (root / 'PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/NearbyLibraryReceiveService.swift').read_text()
bridge = service[service.index('@MainActor final class NearbyImportCompletion'):service.rindex('#endif')]
receipt = service[service.index('struct NearbyLibraryReceipt'):service.index('/// Shares a physical transfer')]
importer = (root / 'PVLibrary/Sources/PVLibrary/Importer/Services/GameImporter/GameImporter.swift').read_text()
method = importer[importer.index('    func addImport(_ item: ImportQueueItem) {'):importer.index('    func addImports(_ items: [ImportQueueItem]) {')]
stubs = '''import Foundation
import Darwin
import Combine
func ILOG(_ message: String) {}
func VLOG(_ message: String) {}
final class ImportQueueItem: ObservableObject, @unchecked Sendable {
    enum Status { case queued, processing, extracting, success, failure(error: Error), conflict, partial
        var blocksDuplicateProcessing: Bool { switch self { case .success, .failure: return false; default: return true } }
    }
    let objectWillChange = ObservableObjectPublisher()
    let id = UUID()
    let url: URL
    var cachedContentMD5: String? = nil
    var status = Status.queued { didSet { objectWillChange.send() } }
    init(_ path: String) { url = URL(fileURLWithPath: path) }
}
@MainActor final class GameImporter {
    static let shared = GameImporter()
    var owned: ImportQueueItem?
    var cleanupCount = 0
    func cancelPendingImports(withIDs ids: Set<UUID>) async {
        cleanupCount += 1
        if let owned, ids.contains(owned.id), case .queued = owned.status { owned.status = .failure(error: CancellationError()) }
    }
}
struct RemoteFile: Codable, Equatable, Sendable { var sha256: String }
struct RemoteManifest { var gameFiles: [RemoteFile] }
@MainActor enum NearbyLibraryReceiveService {
    enum ReceiveError: Error { case incompleteImport }
    static var registration: [URL]?
    static func registeredFiles(gameID: String, system: String) -> [URL]? { registration }
}
actor ImportQueueActor {
    var queue: [ImportQueueItem] = []
    func count() -> Int { queue.count }
'''
tests = '''import XCTest
@testable import NearbyImportHarness
final class NearbyImportCompletionTests: XCTestCase {
    @MainActor func testActualSuccessWaitsForTerminal() async throws {
        let item = ImportQueueItem("/tmp/a")
        let helper = NearbyImportCompletion(item: item)
        let task = Task { try await helper.wait() }
        await Task.yield()
        item.status = .success
        try await task.value
    }
    @MainActor func testCancelledPendingCompletesAndLateAnswerIsHarmless() async {
        let item = ImportQueueItem("/tmp/b")
        GameImporter.shared.owned = item
        let task = Task { try await NearbyImportCompletion(item: item).wait() }
        await Task.yield()
        task.cancel()
        do { try await task.value; XCTFail("cancelled wait succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        item.status = .success
        await Task.yield()
    }
    @MainActor func testCancelledProcessingRetainsOwnerUntilActualTerminal() async {
        let item = ImportQueueItem("/tmp/c")
        item.status = .processing
        GameImporter.shared.owned = item
        var ended = false
        let task = Task { defer { ended = true }; try await NearbyImportCompletion(item: item).wait() }
        await Task.yield()
        task.cancel()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(ended)
        item.status = .success
        do { try await task.value; XCTFail("cancelled wait succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(ended)
    }
    func testTerminalHistoryDoesNotBlockRestoringPurgedROM() async {
        let queue = ImportQueueActor()
        let previous = ImportQueueItem("/tmp/game.iso")
        previous.status = .success
        await queue.addImport(previous)
        await queue.addImport(ImportQueueItem("/tmp/game.iso"))
        let count = await queue.count()
        XCTAssertEqual(count, 2)
    }
    @MainActor func testReceiptRequiresAllRegisteredFilesAndFreshSource() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let primary = folder.appendingPathComponent("game.iso")
        let secondary = folder.appendingPathComponent("second.iso")
        try Data("primary".utf8).write(to: primary)
        try Data("secondary".utf8).write(to: secondary)
        let source = [RemoteFile(sha256: "original")]
        let receipt = NearbyLibraryReceipt(gameID: "id", system: "system", sourceFiles: source,
            files: [NearbyLibraryReceipt.File(primary)!, NearbyLibraryReceipt.File(secondary)!])
        NearbyLibraryReceiveService.registration = [primary, secondary]
        XCTAssertTrue(receipt.isPresent(manifest: RemoteManifest(gameFiles: source)))
        XCTAssertFalse(receipt.isPresent(manifest: RemoteManifest(gameFiles: [RemoteFile(sha256: "changed")])))
        try FileManager.default.removeItem(at: secondary)
        XCTAssertFalse(receipt.isPresent(manifest: RemoteManifest(gameFiles: source)), "missing secondary must invalidate the receipt")
        NearbyLibraryReceiveService.registration = nil
        XCTAssertFalse(receipt.isPresent(manifest: RemoteManifest(gameFiles: source)), "a file alone does not prove Realm registration")
    }
    @MainActor func testReceiptRejectsChangedBytesWithSameSizeAndRestoredMtime() throws {
        let primary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: primary) }
        try Data("primary".utf8).write(to: primary)
        let source = [RemoteFile(sha256: "original")]
        let receipt = NearbyLibraryReceipt(gameID: "id", system: "system", sourceFiles: source, files: [NearbyLibraryReceipt.File(primary)!])
        NearbyLibraryReceiveService.registration = [primary]
        XCTAssertTrue(receipt.isPresent(manifest: RemoteManifest(gameFiles: source)))
        let oldModificationDate = try FileManager.default.attributesOfItem(atPath: primary.path)[.modificationDate] as! Date
        try Data("changed".utf8).write(to: primary)
        try FileManager.default.setAttributes([.modificationDate: oldModificationDate], ofItemAtPath: primary.path)
        XCTAssertFalse(receipt.isPresent(manifest: RemoteManifest(gameFiles: source)))
    }
    func testLiveDuplicateRemainsBlocked() async {
        let queue = ImportQueueActor()
        await queue.addImport(ImportQueueItem("/tmp/game.iso"))
        await queue.addImport(ImportQueueItem("/tmp/game.iso"))
        let count = await queue.count()
        XCTAssertEqual(count, 1)
    }
}
'''
with tempfile.TemporaryDirectory(prefix='provenance-nearby-completion-') as name:
    package = Path(name)
    (package/'Sources').mkdir(); (package/'Tests').mkdir()
    (package/'Sources/Bridge.swift').write_text(stubs + method + '}\n' + receipt + bridge)
    (package/'Tests/BridgeTests.swift').write_text(tests)
    (package/'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "NearbyImportHarness", platforms: [.macOS(.v14)], targets: [
.target(name: "NearbyImportHarness", path: "Sources"),
.testTarget(name: "BridgeTests", dependencies: ["NearbyImportHarness"], path: "Tests")])
''')
    raise SystemExit(subprocess.call(['swift', 'test', '--package-path', str(package), '--jobs', '4']))
