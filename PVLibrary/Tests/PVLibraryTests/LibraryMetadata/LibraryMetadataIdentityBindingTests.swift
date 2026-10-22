import Foundation
import Darwin
import XCTest
import PVLibraryMetadata
@testable import PVLibrary

private actor ReaderBarrier {
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    func suspend() async {
        await withCheckedContinuation { continuation in
            release = continuation
            arrived = true
            arrival?.resume(); arrival = nil
        }
    }
    func wait() async {
        if arrived { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func resume() { release?.resume(); release = nil }
}
private final class FailingWriter: @unchecked Sendable {
    var fail = false
    func write(_ data: Data, _ url: URL) throws {
        if fail {
            // Actual atomic IO failure: a data file cannot replace this nonempty directory.
            try data.write(to: url.deletingLastPathComponent(), options: .atomic)
            return
        }
        try data.write(to: url, options: .atomic)
    }
}
final class LibraryMetadataIdentityBindingTests: XCTestCase {
    var directory: URL!
    var file: URL { directory.appendingPathComponent("game.iso") }
    var persistence: URL { directory.appendingPathComponent("bindings.json") }
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("original".utf8).write(to: file)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func verified(_ disc: Int = 0, _ revision: Int = 0) throws -> VerifiedDiscIdentity {
        try XCTUnwrap(VerifiedDiscIdentity(gameID: "GTEST1", discNumber: disc, revision: revision))
    }
    func service(_ value: VerifiedDiscIdentity? = VerifiedDiscIdentity(gameID: "GTEST1", discNumber: 0, revision: 0)) -> LibraryMetadataIdentityBinding {
        LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in value })
    }
    func testRejectsSanitizedPlaceholderOrMissingFieldsWithoutInventingZeros() {
        for id in ["", "<unknown>", "ID-ABCD", "000000", "      ", " GTEST1", "GTEST1 ", "ABC\n", "AB\u{0}D", "AB-CD1", "HAXX", "0000000000000000"] {
            XCTAssertNil(VerifiedDiscIdentity(gameID: id, discNumber: 0, revision: 0), id)
        }
        XCTAssertNil(VerifiedDiscIdentity(gameID: "GTEST1", discNumber: -1, revision: 0))
        XCTAssertNil(VerifiedDiscIdentity(gameID: "GTEST1", discNumber: 0, revision: -1))
        XCTAssertNotNil(VerifiedDiscIdentity(gameID: "0001000148415858", discNumber: 0, revision: 7))
        XCTAssertNotNil(VerifiedDiscIdentity(gameID: "aBcD12", discNumber: 0, revision: 7))
        XCTAssertNil(VerifiedDiscIdentity(gameID: "GTEST1", discNumber: 256, revision: 0))
        XCTAssertNil(VerifiedDiscIdentity(gameID: "GTEST1", discNumber: 0, revision: 65536))
    }
    func testDiscAndRevisionRemainDistinctAndSurviveRestart() async throws {
        var identities = Set<LibraryMetadataStore.Identity>()
        for (index, value) in try [verified(), verified(1), verified(0, 1)].enumerated() {
            let binding = service(value)
            let identity = try await binding.bind(localGameID: "local\(index)", fileURL: file)
            identities.insert(try XCTUnwrap(identity))
        }
        XCTAssertEqual(identities.count, 3)
        let restarted = service(nil)
        for index in 0..<3 {
            let identity = try await restarted.identity(forLocalGameID: "local\(index)")
            XCTAssertTrue(identities.contains(try XCTUnwrap(identity)))
        }
    }
    func testSameNameDifferentFilesNeverReusesPreviousEvidence() async throws {
        let first = directory.appendingPathComponent("a/game.iso")
        let second = directory.appendingPathComponent("b/game.iso")
        for url in [first, second] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("disc".utf8).write(to: url)
        }
        let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { url in
            VerifiedDiscIdentity(gameID: url == first ? "GTEST1" : "GTEST2", discNumber: 0, revision: 0)
        })
        let a = try await binding.bind(localGameID: "a", fileURL: first)
        let b = try await binding.bind(localGameID: "b", fileURL: second)
        XCTAssertNotEqual(a, b)
    }
    func testReplacementSizeMutationSameLengthRestoredMtimeAndMissingInvalidate() async throws {
        for mutation in 0..<4 {
            try Data("original".utf8).write(to: file)
            let binding = service()
            _ = try await binding.bind(localGameID: "local", fileURL: file)
            var originalStat = stat()
            XCTAssertEqual(stat(file.path, &originalStat), 0)
            switch mutation {
            case 0: try Data("replaced".utf8).write(to: file, options: .atomic)
            case 1: try Data("different size".utf8).write(to: file)
            case 2:
                let handle = try FileHandle(forWritingTo: file)
                try handle.write(contentsOf: Data("modified".utf8)); try handle.close()
                var times = [originalStat.st_atimespec, originalStat.st_mtimespec]
                XCTAssertEqual(utimensat(AT_FDCWD, file.path, &times, 0), 0)
                var modifiedStat = stat()
                XCTAssertEqual(stat(file.path, &modifiedStat), 0)
                XCTAssertEqual(modifiedStat.st_mtimespec.tv_sec, originalStat.st_mtimespec.tv_sec)
                XCTAssertEqual(modifiedStat.st_mtimespec.tv_nsec, originalStat.st_mtimespec.tv_nsec)
            default: try FileManager.default.removeItem(at: file)
            }
            let identity = try await binding.identity(forLocalGameID: "local")
            XCTAssertNil(identity)
            let restarted = service()
            let saved = try await restarted.identity(forLocalGameID: "local")
            XCTAssertNil(saved)
        }
    }
    func testSymlinkRetargetAndNonRegularFile() async throws {
        let link = directory.appendingPathComponent("link.iso")
        let other = directory.appendingPathComponent("other.iso")
        try Data("original".utf8).write(to: other)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let binding = service()
        _ = try await binding.bind(localGameID: "local", fileURL: link)
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: other)
        let identity = try await binding.identity(forLocalGameID: "local")
        XCTAssertNil(identity)
        let folder = try await binding.bind(localGameID: "folder", fileURL: directory)
        XCTAssertNil(folder)
    }
    func testNilAndFailedReaderLeavePendingAndLookupNeverReads() async throws {
        let binding = service(nil)
        let value = try await binding.bind(localGameID: "nil", fileURL: file)
        XCTAssertNil(value)
        let failing = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in throw CocoaError(.fileReadCorruptFile) })
        do { _ = try await failing.bind(localGameID: "fail", fileURL: file); XCTFail("expected operation to fail") } catch {}
        let saved = service()
        _ = try await saved.bind(localGameID: "saved", fileURL: file)
        let lookup = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in XCTFail("lookup parsed ROM"); return nil })
        let identity = try await lookup.identity(forLocalGameID: "saved")
        XCTAssertNotNil(identity)
    }
    func testUnsupportedRebindRemovesPreviousVerifiedBinding() async throws {
        let good = service()
        _ = try await good.bind(localGameID: "local", fileURL: file)
        let pending = service(nil)
        let result = try await pending.bind(localGameID: "local", fileURL: file)
        let lookup = try await pending.identity(forLocalGameID: "local")
        let restarted = service()
        let saved = try await restarted.identity(forLocalGameID: "local")
        XCTAssertNil(result); XCTAssertNil(lookup); XCTAssertNil(saved)
    }
    func testDifferentURLUnsupportedAndFailedRebindCannotExposeOldFileIdentity() async throws {
        let other = directory.appendingPathComponent("different.iso")
        try Data("different".utf8).write(to: other)
        for fail in [false, true] {
            let first = service()
            _ = try await first.bind(localGameID: "local", fileURL: file)
            let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in
                if fail { throw CocoaError(.fileReadCorruptFile) }
                return nil
            })
            do {
                let result = try await binding.bind(localGameID: "local", fileURL: other)
                XCTAssertFalse(fail)
                XCTAssertNil(result)
            } catch { XCTAssertTrue(fail) }
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            let lookup = try await binding.identity(forLocalGameID: "local")
            let restarted = service()
            let persisted = try await restarted.identity(forLocalGameID: "local")
            XCTAssertNil(lookup); XCTAssertNil(persisted)
        }
    }
    func testOversizedAndTooManyRecordsFailClosed() async throws {
        for data in [Data(repeating: 32, count: LibraryMetadataIdentityBinding.maxDocumentBytes + 1),
                     Data(("{\"version\":1,\"records\":[" + Array(repeating: "{}", count: LibraryMetadataIdentityBinding.maxRecords + 1).joined(separator: ",") + "]}").utf8)] {
            try data.write(to: persistence)
            let binding = service()
            do { _ = try await binding.bind(localGameID: "local", fileURL: file); XCTFail("expected operation to fail") } catch {}
            XCTAssertEqual(try Data(contentsOf: persistence), data)
        }
    }
    func testCorruptPersistenceFailsClosedWithoutOverwriting() async throws {
        let corrupt = Data("{corrupt evidence".utf8)
        try corrupt.write(to: persistence)
        let binding = service()
        do { _ = try await binding.identity(forLocalGameID: "local"); XCTFail("expected operation to fail") } catch {}
        do { _ = try await binding.bind(localGameID: "local", fileURL: file); XCTFail("expected operation to fail") } catch {}
        do { try await binding.invalidate(localGameID: "local"); XCTFail("expected operation to fail") } catch {}
        XCTAssertEqual(try Data(contentsOf: persistence), corrupt)
    }
    func testAtomicWriteFailurePreservesPreviousDiskAndCache() async throws {
        let writer = FailingWriter()
        let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in
            VerifiedDiscIdentity(gameID: "GTEST1", discNumber: 0, revision: 0)
        }, writer: { try writer.write($0, $1) })
        let original = try await binding.bind(localGameID: "old", fileURL: file)
        let bytes = try Data(contentsOf: persistence)
        writer.fail = true
        do { _ = try await binding.bind(localGameID: "new", fileURL: file); XCTFail("expected write failure") } catch {}
        let other = directory.appendingPathComponent("new-association.iso")
        try Data("other".utf8).write(to: other)
        do { _ = try await binding.bind(localGameID: "old", fileURL: other); XCTFail("expected replacement write failure") } catch {}
        do { try await binding.invalidate(localGameID: "old"); XCTFail("expected operation to fail") } catch {}
        XCTAssertEqual(try Data(contentsOf: persistence), bytes)
        let old = try await binding.identity(forLocalGameID: "old")
        let new = try await binding.identity(forLocalGameID: "new")
        XCTAssertEqual(old, original); XCTAssertNil(new)
    }
    func testInvalidateAndNewerBindRejectSuspendedOldCompletion() async throws {
        for newerBind in [false, true] {
            let barrier = ReaderBarrier()
            let originalFile = file
            let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { url in
                if url == originalFile { await barrier.suspend() }
                return VerifiedDiscIdentity(gameID: url == originalFile ? "GTEST1" : "GTEST2", discNumber: 0, revision: 0)
            })
            let task = Task { try await binding.bind(localGameID: "local", fileURL: originalFile) }
            await barrier.wait()
            let other = directory.appendingPathComponent("other.iso")
            try Data("other".utf8).write(to: other)
            var expected: LibraryMetadataStore.Identity?
            if newerBind { expected = try await binding.bind(localGameID: "local", fileURL: other)
            } else { try await binding.invalidate(localGameID: "local") }
            await barrier.resume()
            let stale = try await task.value
            let current = try await binding.identity(forLocalGameID: "local")
            XCTAssertNil(stale); XCTAssertEqual(current, expected)
        }
    }
    func testInvalidNewBindStillSupersedesAnOlderSuspendedRead() async throws {
        let barrier = ReaderBarrier()
        let value = try verified()
        let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in await barrier.suspend(); return value })
        let url = file
        let task = Task { try await binding.bind(localGameID: "local", fileURL: url) }
        await barrier.wait()
        do { _ = try await binding.bind(localGameID: "local", fileURL: try XCTUnwrap(URL(string: "https://example.com/game.iso"))); XCTFail("expected operation to fail") } catch {}
        await barrier.resume()
        let stale = try await task.value
        XCTAssertNil(stale)
    }
    func testLookupWhileRebindingIsPendingAndDifferentLocalIDsBothPersist() async throws {
        let first = service()
        _ = try await first.bind(localGameID: "local", fileURL: file)
        let barrier = ReaderBarrier()
        let value = try verified(1)
        let url = file
        let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { source in
            if source == url { await barrier.suspend() }
            return value
        })
        let task = Task { try await binding.bind(localGameID: "local", fileURL: url) }
        await barrier.wait()
        let pending = try await binding.identity(forLocalGameID: "local")
        XCTAssertNil(pending)
        let other = directory.appendingPathComponent("other.iso")
        try Data("other".utf8).write(to: other)
        let second = try await binding.bind(localGameID: "second", fileURL: other)
        await barrier.resume()
        let primary = try await task.value
        let restarted = service(nil)
        let savedPrimary = try await restarted.identity(forLocalGameID: "local")
        let savedSecond = try await restarted.identity(forLocalGameID: "second")
        XCTAssertNotNil(primary); XCTAssertNotNil(second)
        XCTAssertEqual(primary, savedPrimary); XCTAssertEqual(second, savedSecond)
    }
    func testCancelledSuspendedReadAndMutationDuringReadNeverPublish() async throws {
        for cancel in [true, false] {
            let barrier = ReaderBarrier()
            let value = try verified()
            let binding = LibraryMetadataIdentityBinding(localPersistURL: persistence, reader: { _ in await barrier.suspend(); return value })
            let url = file
            let task = Task { try await binding.bind(localGameID: "local", fileURL: url) }
            await barrier.wait()
            if cancel { task.cancel() } else { try Data("mutated".utf8).write(to: file) }
            await barrier.resume()
            do { let result = try await task.value; XCTAssertFalse(cancel); XCTAssertNil(result)
            } catch { XCTAssertTrue(cancel && error is CancellationError) }
            let identity = try await binding.identity(forLocalGameID: "local")
            XCTAssertNil(identity)
        }
    }
}
