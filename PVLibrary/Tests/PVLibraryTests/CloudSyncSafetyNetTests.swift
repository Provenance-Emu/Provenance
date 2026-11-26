import XCTest
import CloudKit
import PVCloudSync
@testable import PVLibrary

final class CloudSyncSafetyNetTests: XCTestCase {
    private var root = URL(fileURLWithPath: NSTemporaryDirectory())
    private var libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    private var trashRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    private var incomingRoot = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncSafetyNetTests-\(UUID().uuidString)", isDirectory: true)
        libraryRoot = root.appendingPathComponent("Documents", isDirectory: true)
        trashRoot = root.appendingPathComponent("Trash", isDirectory: true)
        incomingRoot = root.appendingPathComponent("Incoming", isDirectory: true)
        for folder in [libraryRoot, trashRoot, incomingRoot] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    // MARK: - Replaced files

    func testADifferentLocalFileIsMovedToTheTrashUnderItsLibraryPath() async throws {
        let local = libraryRoot.appendingPathComponent("Battery States/SNES/Game.srm")
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("local progress", to: local)
        try write("cloud progress", to: incoming)
        let trash = SyncTrash(rootURL: trashRoot)

        let entry = await CloudSyncSafetyNet.preserveLocalFile(
            at: local, replacedBy: incoming, libraryRoot: libraryRoot, trash: trash
        )

        XCTAssertEqual(entry?.relativePath, "Battery States/SNES/Game.srm")
        XCTAssertFalse(FileManager.default.fileExists(atPath: local.path))
        let kept = try XCTUnwrap(entry?.url)
        XCTAssertEqual(try String(contentsOf: kept, encoding: .utf8), "local progress")
        let listed = await trash.entries()
        XCTAssertEqual(listed.map(\.relativePath), ["Battery States/SNES/Game.srm"])
    }

    func testAnIdenticalLocalFileIsLeftAlone() async throws {
        let local = libraryRoot.appendingPathComponent("Battery States/SNES/Game.srm")
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("same bytes", to: local)
        try write("same bytes", to: incoming)
        let trash = SyncTrash(rootURL: trashRoot)

        let entry = await CloudSyncSafetyNet.preserveLocalFile(
            at: local, replacedBy: incoming, libraryRoot: libraryRoot, trash: trash
        )

        XCTAssertNil(entry)
        XCTAssertTrue(FileManager.default.fileExists(atPath: local.path))
        let listed = await trash.entries()
        XCTAssertTrue(listed.isEmpty)
    }

    func testAMissingLocalFileKeepsNothing() async throws {
        let local = libraryRoot.appendingPathComponent("Battery States/SNES/Game.srm")
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("cloud progress", to: incoming)

        let entry = await CloudSyncSafetyNet.preserveLocalFile(
            at: local, replacedBy: incoming, libraryRoot: libraryRoot, trash: SyncTrash(rootURL: trashRoot)
        )

        XCTAssertNil(entry)
    }

    func testAFileOutsideTheLibraryIsKeptUnderItsName() async throws {
        let local = root.appendingPathComponent("Elsewhere/Card.raw")
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("local", to: local)
        try write("cloud", to: incoming)

        let entry = await CloudSyncSafetyNet.preserveLocalFile(
            at: local, replacedBy: incoming, libraryRoot: libraryRoot, trash: SyncTrash(rootURL: trashRoot)
        )

        XCTAssertEqual(entry?.relativePath, "Card.raw")
    }

    func testARestoredFileReturnsToItsLibraryPath() async throws {
        let local = libraryRoot.appendingPathComponent("Saves/GBA/Game/slot1.svs")
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("local state", to: local)
        try write("cloud state", to: incoming)
        let trash = SyncTrash(rootURL: trashRoot)
        let kept = await CloudSyncSafetyNet.preserveLocalFile(
            at: local, replacedBy: incoming, libraryRoot: libraryRoot, trash: trash
        )
        let entry = try XCTUnwrap(kept)
        try FileManager.default.copyItem(at: incoming, to: local)

        try await CloudSyncSafetyNet.restore(entry, libraryRoot: libraryRoot, trash: trash)

        XCTAssertEqual(try String(contentsOf: local, encoding: .utf8), "local state")
        // The cloud copy the restore replaced is kept in turn, so the restore can be undone.
        let listed = await trash.entries()
        XCTAssertEqual(listed.count, 1)
        let keptAgain = try XCTUnwrap(listed.first)
        XCTAssertEqual(try String(contentsOf: keptAgain.url, encoding: .utf8), "cloud state")
    }

    func testFilesOlderThanTheRetentionArePurgedOnTheNextKeep() async throws {
        let incoming = incomingRoot.appendingPathComponent("asset")
        try write("cloud", to: incoming)
        let trash = SyncTrash(rootURL: trashRoot)
        let old = libraryRoot.appendingPathComponent("Battery States/NES/Old.sav")
        let recent = libraryRoot.appendingPathComponent("Battery States/NES/Recent.sav")
        try write("old", to: old)
        try write("recent", to: recent)
        let now = Date()
        let longAgo = now.addingTimeInterval(-CloudSyncSafetyNet.trashRetention - 60)

        await CloudSyncSafetyNet.preserveLocalFile(
            at: old, replacedBy: incoming, libraryRoot: libraryRoot, trash: trash, now: longAgo
        )
        await CloudSyncSafetyNet.preserveLocalFile(
            at: recent, replacedBy: incoming, libraryRoot: libraryRoot, trash: trash, now: now
        )

        let listed = await trash.entries()
        XCTAssertEqual(listed.map(\.relativePath), ["Battery States/NES/Recent.sav"])
    }

    // MARK: - Retry

    func testTheServersRetryAfterIsUsed() {
        let error = CKError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 7.0])
        XCTAssertEqual(CloudSyncSafetyNet.retryDelay(after: error, attempt: 1, maximumAttempts: 3), 7.0)
    }

    func testRetriesStopAtTheCallersLimit() {
        let error = CKError(.serviceUnavailable)
        XCTAssertNotNil(CloudSyncSafetyNet.retryDelay(after: error, attempt: 2, maximumAttempts: 3))
        XCTAssertNil(CloudSyncSafetyNet.retryDelay(after: error, attempt: 3, maximumAttempts: 3))
    }

    func testAFullAccountIsNotRetried() {
        XCTAssertNil(CloudSyncSafetyNet.retryDelay(after: CKError(.quotaExceeded), attempt: 1, maximumAttempts: 3))
    }

    func testAChangedServerRecordIsNotRetried() {
        XCTAssertNil(CloudSyncSafetyNet.retryDelay(after: CKError(.serverRecordChanged), attempt: 1, maximumAttempts: 3))
    }
}
