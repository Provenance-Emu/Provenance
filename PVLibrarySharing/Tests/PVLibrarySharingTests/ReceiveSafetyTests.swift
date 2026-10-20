import Foundation
import PVSystems
import XCTest
@testable import PVLibrarySharing

private actor SafetySource: LibrarySource {
    nonisolated let app = PeerApp.iCube
    let bytes = Data("abc".utf8)
    let manifest: RemoteManifest
    var downloadCalls = 0
    var downloadEntered = false
    var blockDownload = false
    var pending: CheckedContinuation<Void, Never>?

    init() {
        manifest = RemoteManifest(itemId: "game", files: [RemoteFile(kind: "gameFile", relativePath: "Software/game.rvz",
            sha256: sha256Hex(Data("abc".utf8)), size: 3)])
    }
    func setBlocked() { blockDownload = true }
    func unblock() { pending?.resume(); pending = nil }
    func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        RemoteCatalogue(deviceName: "iCube", items: [], source: app)
    }
    func artwork(for item: RemoteLibraryItem) async throws -> Data? { nil }
    func pullManifest(for item: RemoteLibraryItem, progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteManifest { manifest }
    func download(_ file: RemoteFile, of manifest: RemoteManifest, to partialFile: URL, resumeOffset: Int64,
                  progress: @escaping @Sendable (Int64) -> Void) async throws -> LibraryDownloadResponse {
        downloadCalls += 1
        try bytes.write(to: partialFile)
        downloadEntered = true
        if blockDownload { await withCheckedContinuation { pending = $0 } }
        return LibraryDownloadResponse(status: 200, writtenFrom: 0, bytesOnDisk: Int64(bytes.count))
    }
}

final class ReceiveSafetyTests: XCTestCase {
    private func item() -> RemoteLibraryItem {
        RemoteLibraryItem(id: "game", title: "Game", platform: "gc", systemIdentifier: .GameCube,
                          md5: nil, sizeBytes: 3, artKey: nil, source: .iCube)
    }

    func testExistingSameSizeStagingFileIsHashedBeforeReuse() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = SafetySource()
        let puller = LibraryPuller(staging: .init(root: root), peerKey: "source")
        let first = try await puller.pull(item(), from: source) { _ in }
        try Data("xyz".utf8).write(to: first.primaryFile)
        let retried = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(try Data(contentsOf: retried.primaryFile), Data("abc".utf8))
        let calls = await source.downloadCalls
        XCTAssertEqual(calls, 2)
    }

    func testCancellationAfterSuccessfulDelegateDoesNotFinalize() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = SafetySource()
        await source.setBlocked()
        let puller = LibraryPuller(staging: .init(root: root), peerKey: "source")
        let item = item()
        let job = Task { try await puller.pull(item, from: source) { _ in } }
        for _ in 0..<10000 {
            if await source.downloadEntered { break }
            await Task.yield()
        }
        job.cancel()
        await source.unblock()
        do { _ = try await job.value; XCTFail("Cancelled copy returned success") } catch is CancellationError {} catch { XCTFail("Unexpected \(error)") }
        let folder = puller.folder(for: item, from: .iCube)
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "Software/game.rvz", in: folder))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathExtension("part").path))
    }

    func testStagingRejectsSymlinkAncestorWhenLeafDoesNotExist() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: outside) }
        let files = root.appendingPathComponent("files")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: files.appendingPathComponent("escape"), withDestinationURL: outside)
        XCTAssertNil(LibraryStaging.containedURL(for: "escape/game.rvz", in: root))
    }
    func testStagingFilesBaseSymlinkIsRejectedBeforeDownload() async throws {
        try await assertStageSymlinkRejected(linkFilesBase: true)
    }

    func testHashedStagingFolderSymlinkIsRejectedBeforeManifestWrite() async throws {
        try await assertStageSymlinkRejected(linkFilesBase: false)
    }

    private func assertStageSymlinkRejected(linkFilesBase: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let source = SafetySource()
        let puller = LibraryPuller(staging: .init(root: root), peerKey: "source")
        let folder = puller.folder(for: item(), from: .iCube)
        if linkFilesBase { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let link = linkFilesBase ? folder.appendingPathComponent("files") : folder
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        do { _ = try await puller.pull(item(), from: source) { _ in }; XCTFail("redirected staging succeeded") } catch {}
        let calls = await source.downloadCalls
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outside.path), [])
    }

}
