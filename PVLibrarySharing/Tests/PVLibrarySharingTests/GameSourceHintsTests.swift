import XCTest
@testable import PVLibrarySharing

final class GameSourceHintsTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("hints-" + UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    private var hint: GameSourceHint {
        GameSourceHint(
            app: .iCube, sourceIdentity: "peer-1", remoteItemID: "item-9",
            files: [MissingGameFile(name: "Game.iso", size: 42, isPrimary: true)], standInMD5: nil
        )
    }

    func testRoundTripsThroughDisk() async {
        let url = folder.appendingPathComponent("hints.json")
        await GameSourceHints(fileURL: url).record(hint, forMD5: "ABC")
        let read = await GameSourceHints(fileURL: url).hint(forMD5: "ABC")
        XCTAssertEqual(read, hint)
    }

    func testKeysAreCaseInsensitive() async {
        let store = GameSourceHints(fileURL: folder.appendingPathComponent("hints.json"))
        await store.record(hint, forMD5: "abc")
        let read = await store.hint(forMD5: "ABC")
        XCTAssertNotNil(read)
        await store.remove(md5: "Abc")
        let gone = await store.hint(forMD5: "abc")
        XCTAssertNil(gone)
    }

    func testCorruptFileReadsAsEmpty() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("hints.json")
        try Data("not json".utf8).write(to: url)
        let store = GameSourceHints(fileURL: url)
        let before = await store.hint(forMD5: "ABC")
        XCTAssertNil(before)
        await store.record(hint, forMD5: "ABC")
        let after = await GameSourceHints(fileURL: url).hint(forMD5: "ABC")
        XCTAssertEqual(after, hint)
    }

    func testMissingFolderIsCreatedOnRecord() async {
        let url = folder.appendingPathComponent("deep/er/hints.json")
        await GameSourceHints(fileURL: url).record(hint, forMD5: "ABC")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
