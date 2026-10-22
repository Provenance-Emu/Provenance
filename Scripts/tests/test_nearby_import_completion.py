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
admission = service[service.index('        let queued = ImportQueueItem'):service.index('        let computedMD5')]
claim = (root / 'PVLibrary/Sources/PVLibrary/Importer/Models/ImportQueueClaim.swift').read_text()
item_source = (root / 'PVLibrary/Sources/PVLibrary/Importer/Models/ImportQueueItem.swift').read_text()
item_claim = item_source[item_source.index('    let processingClaim ='):item_source.index('    /// Notify SwiftUI observers')]
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
    var requiresContentBasedDuplicateCheck = false
    var userChosenSystem: String?
    init(url: URL) { self.url = url }
    convenience init(_ path: String) { self.init(url: URL(fileURLWithPath: path)) }
''' + item_claim + '''
}
@MainActor final class GameImporter {
    static let shared = GameImporter()
    var owned: ImportQueueItem?
    var cleanupCount = 0
    var barrier: AdmissionBarrier?
    var workerClaims = 0
    var suspendAfterInsertion = false
    var importQueue: [ImportQueueItem] { get async { await queue.items() } }
    let queue = ImportQueueActor()
    func addImport(_ item: ImportQueueItem) async {
        owned = item
        if let barrier, !suspendAfterInsertion { await barrier.suspendAdmission() }
        await queue.addImport(item)
        if let barrier, suspendAfterInsertion { await barrier.suspendAdmission() }
        // A running worker can take a queue snapshot before addImport returns.
        if await queue.items().contains(where: { $0.id == item.id }), item.processingClaim.claim() {
            workerClaims += 1
            item.status = .success
            item.processingClaim.finish()
        }
    }
    func startProcessing() {}
    func cancelPendingImports(withIDs ids: Set<UUID>) async {
        cleanupCount += 1
        if let owned, ids.contains(owned.id), case .queued = owned.status { _ = owned.cancelBeforeProcessing() }
    }
}
struct RemoteFile: Codable, Equatable, Sendable { var sha256: String }
struct RemoteManifest { var gameFiles: [RemoteFile] }
@MainActor enum NearbyLibraryReceiveService {
    enum ReceiveError: Error { case incompleteImport }
    static func admit(_ url: URL) async throws {
        let pulled = (primaryFile: url, ignored: false)
        let system = "system"
        let checkEligibility: @MainActor () throws -> Void = {}
''' + admission + '''
    }
    static var registration: [URL]?
    static func registeredFiles(gameID: String, system: String) -> [URL]? { registration }
}
actor ImportQueueActor {
    var queue: [ImportQueueItem] = []
    func count() -> Int { queue.count }
    func items() -> [ImportQueueItem] { queue }
'''
barrier = '''
actor AdmissionBarrier {
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    func suspendAdmission() async {
        await withCheckedContinuation { continuation in
            release = continuation
            arrived = true
            arrival?.resume(); arrival = nil
        }
    }
    func waitForAdmission() async {
        if arrived { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func resumeAdmission() { release?.resume(); release = nil }
}
'''
tests = '''import XCTest
@testable import NearbyImportHarness
final class NearbyImportCompletionTests: XCTestCase {
    @MainActor func testCancellationWhileAdmissionSuspendedPreventsRunningWorkerClaim() async {
        let importer = GameImporter.shared
        let barrier = AdmissionBarrier()
        importer.barrier = barrier
        importer.workerClaims = 0
        defer { importer.barrier = nil }
        let task = Task { try await NearbyLibraryReceiveService.admit(URL(fileURLWithPath: "/tmp/barrier.iso")) }
        await barrier.waitForAdmission()
        task.cancel()
        await barrier.resumeAdmission()
        do { try await task.value; XCTFail("cancelled admission succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(importer.workerClaims, 0, "a worker claimed the item after its owner cancelled during admission")
    }
    @MainActor func testCancellationAfterInsertionPreventsWorkerClaimAndRemovesPendingItem() async {
        let importer = GameImporter.shared
        let barrier = AdmissionBarrier()
        importer.barrier = barrier
        importer.suspendAfterInsertion = true
        importer.workerClaims = 0
        defer { importer.barrier = nil; importer.suspendAfterInsertion = false }
        let task = Task { try await NearbyLibraryReceiveService.admit(URL(fileURLWithPath: "/tmp/inserted.iso")) }
        await barrier.waitForAdmission()
        task.cancel()
        await barrier.resumeAdmission()
        do { try await task.value; XCTFail("cancelled admission succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(importer.workerClaims, 0)
        guard let item = importer.owned else { return XCTFail("no admission") }
        if case .failure = item.status {} else { XCTFail("pending cancellation did not finish cleanup") }
    }
    func testCancelledItemIsRejectedByActualQueueAdmission() async {
        let queue = ImportQueueActor()
        let item = ImportQueueItem("/tmp/pre-cancelled.iso")
        XCTAssertTrue(item.processingClaim.cancelPending())
        await queue.addImport(item)
        let count = await queue.count()
        XCTAssertEqual(count, 0)
    }
    @MainActor func testVerifiedReceiveSelectsContentBasedAdmission() async throws {
        try await NearbyLibraryReceiveService.admit(URL(fileURLWithPath: "/tmp/verified-content.iso"))
        XCTAssertTrue(GameImporter.shared.owned?.requiresContentBasedDuplicateCheck == true)
    }
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
    (package/'Sources/Bridge.swift').write_text(claim + stubs + method + '}\n' + receipt + bridge + barrier)
    (package/'Tests/BridgeTests.swift').write_text(tests)
    (package/'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "NearbyImportHarness", platforms: [.macOS(.v14)], targets: [
.target(name: "NearbyImportHarness", path: "Sources"),
.testTarget(name: "BridgeTests", dependencies: ["NearbyImportHarness"], path: "Tests")])
''')
    raise SystemExit(subprocess.call(['swift', 'test', '--package-path', str(package), '--jobs', '4']))
