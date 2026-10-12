//
//  LibraryMoveFileCopierTests.swift
//  PVLibraryTests
//

import XCTest
import PVHashing
@testable import PVFileSystem

/// MD5 that returns whatever the test says, so verification failures can be forced.
private final class StubMD5: MD5Provider, @unchecked Sendable {
    var answers: [String: String] = [:]   // path suffix → md5
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String? {
        for (suffix, md5) in answers where url.path.hasSuffix(suffix) { return md5 }
        return FileManager.default.md5ForFile(at: url, fromOffset: 0)
    }
}

final class LibraryMoveFileCopierTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveFileCopierTests")
        src = base.appendingPathComponent("src", isDirectory: true)
        dst = base.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func write(_ root: URL, _ relativePath: String, _ text: String) throws -> LibraryMovePlan.Item {
        try LibraryMoveTestSupport.write(root, relativePath, text)
        return try LibraryMoveTestSupport.planItem(root, relativePath)
    }

    func testCopiesIntoAFreshDestinationAndRecordsMD5ForROMs() throws {
        let item = try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom bytes")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertEqual(entry?.size, item.size)
        XCTAssertEqual(entry?.modified, item.modified)
        XCTAssertEqual(entry?.md5, FileManager.default.md5ForFile(at: src.appendingPathComponent(item.relativePath), fromOffset: 0))
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom bytes")
        XCTAssertEqual(LibraryMoveTestSupport.read(src, "ROMs/com.provenance.snes/Game.sfc"), "rom bytes", "the source is left for cleanup")
    }

    func testSizeOnlyFoldersSkipMD5() throws {
        let item = try write(src, "Save States/Game/s.svs", "state")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertNil(entry?.md5)
        XCTAssertTrue(LibraryMoveFileCopier.needsMD5("ROMs/x/y"))
        XCTAssertTrue(LibraryMoveFileCopier.needsMD5("BIOS/x"))
        XCTAssertFalse(LibraryMoveFileCopier.needsMD5("Save States/x"))
    }

    func testLooseTopLevelFileIsCopied() throws {
        let item = try write(src, "loose.txt", "hello")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "loose.txt"), "hello")
    }

    func testIdenticalDestinationIsRecordedNotCopied() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "same")
        _ = try write(dst, "ROMs/a/Game.sfc", "same")
        let before = try LibraryMoveTestSupport.modificationDate(dst, item.relativePath)
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .identical)
        XCTAssertEqual(before, try LibraryMoveTestSupport.modificationDate(dst, item.relativePath), "an identical destination file is not rewritten")
    }

    func testDifferentDestinationSendsTheIncomingFileToConflicts() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .conflict)
        XCTAssertEqual(entry?.destinationPath, "Conflicts/ROMs/a/Game.sfc")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "ROMs/a/Game.sfc"), "existing", "the destination is never overwritten")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/ROMs/a/Game.sfc"), "incoming")
    }

    func testSecondConflictGetsANumberedName() throws {
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        _ = try write(dst, "Conflicts/ROMs/a/Game.sfc", "earlier conflict")
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.destinationPath, "Conflicts/ROMs/a/Game-2.sfc")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/ROMs/a/Game-2.sfc"), "incoming")
    }

    func testSameSizeDifferentContentInAnMD5FolderIsAConflict() throws {
        let item = try write(src, "BIOS/bios.bin", "aaaa")
        _ = try write(dst, "BIOS/bios.bin", "bbbb")
        XCTAssertEqual(try LibraryMoveFileCopier().transfer(item, from: src, to: dst)?.state, .conflict)
    }

    func testSameSizeDifferentContentInASizeOnlyFolderIsAConflict() throws {
        let item = try write(src, "Battery States/G/G.srm", "AAAA")
        _ = try write(dst, "Battery States/G/G.srm", "BBBB")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .conflict, "a fixed-size save must not be called identical on size alone")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Battery States/G/G.srm"), "BBBB")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/Battery States/G/G.srm"), "AAAA")
    }

    func testSameContentInASizeOnlyFolderIsIdentical() throws {
        let item = try write(src, "Battery States/G/G.srm", "AAAA")
        _ = try write(dst, "Battery States/G/G.srm", "AAAA")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .identical)
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "Conflicts"))
    }

    func testVanishedSourceReturnsNil() throws {
        let item = LibraryMovePlan.Item(relativePath: "ROMs/gone.sfc", size: 3, modified: nil)
        XCTAssertNil(try LibraryMoveFileCopier().transfer(item, from: src, to: dst))
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "ROMs/gone.sfc"))
    }

    func testVerificationFailureRemovesThePartialCopyAndThrows() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "rom")
        let md5 = StubMD5()
        // The copy is verified at its hidden temp name, before the rename, so that is the path that must hash "wrong".
        md5.answers["dst/ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix] = "deadbeef"
        XCTAssertThrowsError(try LibraryMoveFileCopier(md5Provider: md5).transfer(item, from: src, to: dst)) { error in
            XCTAssertEqual(error as? LibraryMoveError, .verificationFailed(relativePath: "ROMs/a/Game.sfc"))
        }
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "ROMs/a/Game.sfc"))
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix), "the failed temp file is removed")
    }

    func testAStalePartialIsReplacedAndNeverPlanned() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "rom")
        let stale = "ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix
        _ = try write(dst, stale, "garbage left by a crash")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "ROMs/a/Game.sfc"), "rom")
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, stale), "the temp file is renamed away")
        let planned = try LibraryMovePlanner().plan(root: dst, folders: ["ROMs"])
        XCTAssertEqual(planned.items.map(\.relativePath), ["ROMs/a/Game.sfc"], "a temp file is hidden, so the planner never sees it")
    }

    // MARK: - Copy-phase conflicts: the destination's own file is moved aside

    func testDisplacePolicyMovesTheExistingFileAsideAndPutsTheIncomingFileAtTheRealPath() throws {
        let item = try write(src, "Battery States/G/G.srm", "LIVE")
        _ = try write(dst, "Battery States/G/G.srm", "OLD!")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst, onConflict: .displaceExisting)
        XCTAssertEqual(entry?.state, .displaced)
        XCTAssertNil(entry?.destinationPath, "the incoming file is at the real path")
        XCTAssertEqual(entry?.displacedPath, "Conflicts/Battery States/G/G.srm")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Battery States/G/G.srm"), "LIVE")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/Battery States/G/G.srm"), "OLD!", "nothing is deleted")
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "Battery States/G/.G.srm" + LibraryMoveFileCopier.partialSuffix))
    }

    func testDisplacedFilesGetNumberedNamesWhenConflictsIsTaken() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        _ = try write(dst, "Conflicts/ROMs/a/Game.sfc", "earlier")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst, onConflict: .displaceExisting)
        XCTAssertEqual(entry?.displacedPath, "Conflicts/ROMs/a/Game-2.sfc")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/ROMs/a/Game.sfc"), "earlier")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/ROMs/a/Game-2.sfc"), "existing")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "ROMs/a/Game.sfc"), "incoming")
    }

    func testDisplacePolicyStillCallsAnIdenticalFileIdenticalAndMovesNothing() throws {
        let item = try write(src, "Battery States/G/G.srm", "SAME")
        _ = try write(dst, "Battery States/G/G.srm", "SAME")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst, onConflict: .displaceExisting)
        XCTAssertEqual(entry?.state, .identical)
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "Conflicts"))
    }

    func testDisplacePolicyFilesIncomingUnderConflictsWhenTheDestinationPathIsAFolder() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        try FileManager.default.createDirectory(at: dst.appendingPathComponent("ROMs/a/Game.sfc"), withIntermediateDirectories: true)
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst, onConflict: .displaceExisting)
        XCTAssertEqual(entry?.state, .conflict, "a folder is never moved aside")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/ROMs/a/Game.sfc"), "incoming")
    }

    func testDisplacePolicyLeavesTheExistingFileInPlaceWhenTheIncomingCopyFailsVerification() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        let md5 = StubMD5()
        md5.answers["dst/ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix] = "deadbeef"
        XCTAssertThrowsError(try LibraryMoveFileCopier(md5Provider: md5).transfer(item, from: src, to: dst, onConflict: .displaceExisting))
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "ROMs/a/Game.sfc"), "existing", "nothing is moved aside until the incoming copy has verified")
        XCTAssertFalse(LibraryMoveTestSupport.exists(dst, "Conflicts"))
    }

    func testVerifyChecksSizeAndOptionalMD5() throws {
        let item = try write(dst, "ROMs/a/Game.sfc", "rom")
        let url = dst.appendingPathComponent(item.relativePath)
        let copier = LibraryMoveFileCopier()
        XCTAssertTrue(copier.verify(url, expectedSize: 3, expectedMD5: nil))
        XCTAssertFalse(copier.verify(url, expectedSize: 4, expectedMD5: nil))
        XCTAssertTrue(copier.verify(url, expectedSize: 3, expectedMD5: FileManager.default.md5ForFile(at: url, fromOffset: 0)))
        XCTAssertFalse(copier.verify(url, expectedSize: 3, expectedMD5: "nope"))
        XCTAssertFalse(copier.verify(dst.appendingPathComponent("missing"), expectedSize: 0, expectedMD5: nil))
    }

    func testTransferAsConflictFilesASameSizeSourceUnderConflictsEvenInAnUnhashedFolder() throws {
        _ = try write(dst, "Battery States/Game/Game.srm", "AAAA")
        let item = try write(src, "Battery States/Game/Game.srm", "BBBB")
        let entry = try LibraryMoveFileCopier().transferAsConflict(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .conflict)
        XCTAssertEqual(entry?.destinationPath, "Conflicts/Battery States/Game/Game.srm")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Battery States/Game/Game.srm"), "AAAA", "the verified copy is never overwritten")
        XCTAssertEqual(LibraryMoveTestSupport.read(dst, "Conflicts/Battery States/Game/Game.srm"), "BBBB")
    }

    func testTransferAsConflictSkipsASourceThatIsGone() throws {
        let item = LibraryMovePlan.Item(relativePath: "ROMs/a/Gone.sfc", size: 1, modified: nil)
        XCTAssertNil(try LibraryMoveFileCopier().transferAsConflict(item, from: src, to: dst))
    }
}
