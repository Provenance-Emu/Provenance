import XCTest
@testable import PVLibrarySharing

final class MissingGameRestorerTests: XCTestCase {
    private var root: URL!
    private var staging: LibraryStaging!
    private var stagedFolder: URL!
    private var library: URL!
    private let manager = FileManager.default

    override func setUpWithError() throws {
        root = manager.temporaryDirectory.appendingPathComponent("restore-" + UUID().uuidString, isDirectory: true)
        staging = LibraryStaging(root: root.appendingPathComponent("staging", isDirectory: true))
        stagedFolder = staging.folder(peerKey: "peer", app: .pvLibrary, itemId: "item")
        library = root.appendingPathComponent("ROMs/com.provenance.n64", isDirectory: true)
        try manager.createDirectory(at: stagedFolder.appendingPathComponent("files"), withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? manager.removeItem(at: root)
    }

    private func pulled(_ files: [String: String]) throws -> PulledGame {
        var urls: [URL] = []
        for (name, text) in files.sorted(by: { $0.key < $1.key }) {
            let url = stagedFolder.appendingPathComponent("files").appendingPathComponent(name)
            try Data(text.utf8).write(to: url)
            urls.append(url)
        }
        return PulledGame(folder: stagedFolder, gameFiles: urls, primaryFile: urls[0], systemIdentifier: .N64, skippedKinds: [])
    }

    private func target(_ name: String, primary: Bool = true) -> RestoreTarget {
        RestoreTarget(
            file: MissingGameFile(name: name, size: 0, isPrimary: primary), url: library.appendingPathComponent(name)
        )
    }

    private func text(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    private func leftovers() -> [String] {
        ((try? manager.contentsOfDirectory(atPath: library.path)) ?? [])
            .filter { $0.hasPrefix(MissingGameRestorer.temporaryPrefix) }
    }

    func testRestoresMissingFile() throws {
        let game = target("Game.z64")
        let result = try MissingGameRestorer.restore(try pulled(["game.z64": "new"]), to: [game], kind: .exact, staging: staging)
        XCTAssertEqual(text(at: game.url), "new")
        XCTAssertEqual(result, RestoreResult(restored: [game.url], alreadyPresent: []))
        XCTAssertTrue(leftovers().isEmpty)
        XCTAssertTrue(manager.fileExists(atPath: stagedFolder.appendingPathComponent(".handed-off").path))
    }

    func testNeverOverwritesExistingFile() throws {
        let game = target("Game.z64")
        try manager.createDirectory(at: library, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: game.url)
        let result = try MissingGameRestorer.restore(try pulled(["Game.z64": "new"]), to: [game], kind: .exact, staging: staging)
        XCTAssertEqual(text(at: game.url), "old")
        XCTAssertEqual(result, RestoreResult(restored: [], alreadyPresent: [game.url]))
    }

    func testFileAppearingMidRestoreWins() throws {
        let game = target("Game.z64")
        let result = try MissingGameRestorer.restore(
            try pulled(["Game.z64": "new"]), to: [game], kind: .exact, staging: staging, fileManager: manager,
            beforePlacing: { url in try? Data("late".utf8).write(to: url) }
        )
        XCTAssertEqual(text(at: game.url), "late")
        XCTAssertEqual(result, RestoreResult(restored: [], alreadyPresent: [game.url]))
        XCTAssertTrue(leftovers().isEmpty)
    }

    func testRestoresOnlyTheMissingFileOfASet() throws {
        let cue = target("Game.cue")
        let bin = target("Game.bin", primary: false)
        try manager.createDirectory(at: library, withIntermediateDirectories: true)
        try Data("local cue".utf8).write(to: cue.url)
        let copy = try pulled(["Game.cue": "remote cue", "Game.bin": "remote bin"])
        let result = try MissingGameRestorer.restore(copy, to: [cue, bin], kind: .exact, staging: staging)
        XCTAssertEqual(text(at: cue.url), "local cue")
        XCTAssertEqual(text(at: bin.url), "remote bin")
        XCTAssertEqual(result, RestoreResult(restored: [bin.url], alreadyPresent: [cue.url]))
    }

    func testStandInTakesTheOldFileName() throws {
        let game = target("Game.z64")
        let result = try MissingGameRestorer.restore(try pulled(["Other.n64": "new"]), to: [game], kind: .standIn, staging: staging)
        XCTAssertEqual(text(at: game.url), "new")
        XCTAssertEqual(result.restored, [game.url])
        XCTAssertFalse(manager.fileExists(atPath: library.appendingPathComponent("Other.n64").path))
    }

    func testExactNeverRenamesADifferentFile() throws {
        let game = target("Game.z64")
        XCTAssertThrowsError(
            try MissingGameRestorer.restore(try pulled(["Other.n64": "new"]), to: [game], kind: .exact, staging: staging)
        ) { XCTAssertEqual($0 as? MissingGameRestoreError, .fileSetMismatch("Game.z64")) }
        XCTAssertFalse(manager.fileExists(atPath: game.url.path))
    }

    func testMismatchedSetThrowsBeforeMoving() throws {
        let cue = target("Game.cue")
        let bin = target("Game (Track 2).bin", primary: false)
        let copy = try pulled(["Game.cue": "cue", "Game (Track 1).bin": "bin"])
        XCTAssertThrowsError(try MissingGameRestorer.restore(copy, to: [cue, bin], kind: .exact, staging: staging))
        XCTAssertFalse(manager.fileExists(atPath: cue.url.path))
        XCTAssertTrue(leftovers().isEmpty)
        XCTAssertTrue(manager.fileExists(atPath: copy.gameFiles[0].path))
    }
}
