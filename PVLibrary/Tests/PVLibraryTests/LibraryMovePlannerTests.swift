//
//  LibraryMovePlannerTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMovePlannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMovePlannerTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(root)
    }

    private func seed(_ relativePath: String, _ bytes: Int) throws {
        try LibraryMoveTestSupport.write(root, relativePath, bytes: bytes)
    }

    func testPlansOnlyTheListedFoldersRecursively() throws {
        try seed("ROMs/com.provenance.snes/Game.sfc", 10)
        try seed("ROMs/com.provenance.nes/Sub/Deep.nes", 5)
        try seed("BIOS/scph1001.bin", 3)
        try seed("Imports/pending.zip", 1)
        try seed("Skins/other.deltaskin", 100)
        try seed("stray.txt", 100)

        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs", "BIOS"])

        XCTAssertEqual(plan.items.map(\.relativePath).sorted(),
                       ["BIOS/scph1001.bin", "ROMs/com.provenance.nes/Sub/Deep.nes", "ROMs/com.provenance.snes/Game.sfc"])
        XCTAssertEqual(plan.totalBytes, 18)
        XCTAssertNotNil(plan.items.first?.modified)
    }

    func testMissingFoldersAreSkippedNotErrors() throws {
        try seed("BIOS/a.bin", 1)
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs", "BIOS", "Nope"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["BIOS/a.bin"])
    }

    func testHiddenFilesRealmFilesAndTheJournalAreNeverPlanned() throws {
        try seed("ROMs/.DS_Store", 1)
        try seed("ROMs/com.provenance.snes/.hidden", 1)
        try seed("ROMs/com.provenance.snes/Game.sfc", 2)
        try seed("ROMs/default.realm", 9)
        try seed("ROMs/default.realm.lock", 9)
        try seed("ROMs/default.realm.management/lockfile", 9)
        try seed("ROMs/move-journal.json", 9)
        try seed("ROMs/com.provenance.snes/.Game.sfc" + LibraryMoveFileCopier.partialSuffix, 9)
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["ROMs/com.provenance.snes/Game.sfc"])
    }

    func testPlanThrowsWhenASubfolderCannotBeRead() throws {
        try seed("ROMs/open/Game.sfc", 1)
        try seed("ROMs/locked/Hidden.sfc", 1)
        let locked = root.appendingPathComponent("ROMs/locked").path
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
        addTeardownBlock {
            // Runs before tearDownWithError's removeTree could fail on an unreadable folder.
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
        }
        XCTAssertThrowsError(try LibraryMovePlanner().plan(root: root, folders: ["ROMs"]),
                             "a plan that silently dropped files would let the switch happen with an incomplete copy")
    }

    func testSymlinksAreLeftOutOfThePlan() throws {
        try seed("ROMs/a/Game.sfc", 2)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("ROMs/a/link.sfc"),
                                                   withDestinationURL: root.appendingPathComponent("ROMs/a/Game.sfc"))
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["ROMs/a/Game.sfc"])
    }

    func testRelativePathsSurviveThePrivateVarSymlink() throws {
        // On device the root is /var/... but enumeration can yield /private/var/...; both must strip to the same relative path.
        try seed("ROMs/x/Game.sfc", 1)
        let resolved = root.resolvingSymlinksInPath()
        let plan = try LibraryMovePlanner().plan(root: resolved, folders: ["ROMs"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["ROMs/x/Game.sfc"])
    }

    // MARK: - Top-level entries (leaving the App Group moves everything, not a fixed list)

    func testTopLevelEntriesIncludesUnknownFoldersAndLooseFiles() throws {
        try seed("ROMs/a/Game.sfc", 1)
        try seed("Azahar/sdmc/title.cia", 2)
        try seed("DeltaSkins/skin.deltaskin", 3)
        try seed("loose.txt", 4)
        XCTAssertEqual(try LibraryMovePlanner().topLevelEntries(at: root), ["Azahar", "DeltaSkins", "ROMs", "loose.txt"])
    }

    func testTopLevelEntriesSkipsHiddenRealmAndNeverMovedNames() throws {
        try seed("ROMs/a/Game.sfc", 1)
        try seed(".DS_Store", 1)
        try seed(".Trash/x", 1)
        try seed("default.realm", 9)
        try seed("default.realm.lock", 9)
        try seed("default.realm.management/lockfile", 9)
        try seed("move-journal.json", 9)
        XCTAssertEqual(try LibraryMovePlanner().topLevelEntries(at: root), ["ROMs"])
    }

    func testTopLevelEntriesThrowsForAMissingRoot() {
        XCTAssertThrowsError(try LibraryMovePlanner().topLevelEntries(at: root.appendingPathComponent("missing")))
    }

    func testPlanAcceptsLooseTopLevelFilesAndUnknownFolders() throws {
        try seed("loose.txt", 4)
        try seed("Azahar/sdmc/title.cia", 2)
        try seed("DeltaSkins/skin.deltaskin", 3)
        let planner = LibraryMovePlanner()
        let plan = try planner.plan(root: root, folders: try planner.topLevelEntries(at: root))
        XCTAssertEqual(plan.items.map(\.relativePath), ["Azahar/sdmc/title.cia", "DeltaSkins/skin.deltaskin", "loose.txt"])
        XCTAssertEqual(plan.totalBytes, 9)
        XCTAssertNotNil(plan.items.last?.modified)
    }

    func testPlanSkipsAnExcludedTopLevelName() throws {
        try seed("move-journal.json", 9)
        try seed("default.realm", 9)
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["move-journal.json", "default.realm"])
        XCTAssertTrue(plan.items.isEmpty)
    }

    // MARK: - Space

    func testRequiredBytesAddsHeadroom() {
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: 0), LibraryMovePlanner.minimumHeadroomBytes)
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: 1_000), 1_000 + LibraryMovePlanner.minimumHeadroomBytes)
        let big: Int64 = 100 * 1024 * 1024 * 1024 // 100 GB → 5% is larger than the minimum headroom
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: big), big + big / 20)
    }

    func testCheckSpaceThrowsWhenTheDestinationIsTooSmall() throws {
        try seed("ROMs/Game.sfc", 1_000)
        let planner = LibraryMovePlanner(availableCapacity: { _ in 500 })
        let plan = try planner.plan(root: root, folders: ["ROMs"])
        XCTAssertThrowsError(try planner.checkSpace(for: plan, at: root)) { error in
            XCTAssertEqual(error as? LibraryMoveError, .insufficientSpace(required: LibraryMovePlanner.requiredBytes(for: 1_000), available: 500))
        }
    }

    func testCheckSpacePassesWithRoom() throws {
        try seed("ROMs/Game.sfc", 1_000)
        let planner = LibraryMovePlanner(availableCapacity: { _ in .max })
        XCTAssertNoThrow(try planner.checkSpace(for: try planner.plan(root: root, folders: ["ROMs"]), at: root))
    }

    func testDefaultCapacityReadsTheVolume() throws {
        XCTAssertGreaterThan(try LibraryMovePlanner().availableCapacity(root), 0)
    }
}
