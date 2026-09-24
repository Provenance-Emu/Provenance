import XCTest
import PVLibrarySnapshot
@testable import PVQuickLookSupport

final class SnapshotGamePreviewDataSourceTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        super.setUp()
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
        super.tearDown()
    }

    func testGameFromIndex() {
        let game = LibraryIndexGame(filename: "Chrono Trigger.sfc", title: "Chrono Trigger", systemName: "Super Nintendo",
                                    systemIdentifier: "com.provenance.snes", developer: "Square", publishDate: "1995",
                                    genre: "RPG", gameDescription: "Time travel.", playCount: 7, isFavorite: true,
                                    artworkKey: "ct_art")
        _ = LibraryIndexWriter(containerURL: container).write(games: [game], saveStates: [])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        let info = source.game(forROMFilename: "Chrono Trigger.sfc")
        XCTAssertEqual(info?.title, "Chrono Trigger")
        XCTAssertEqual(info?.systemName, "Super Nintendo")
        XCTAssertEqual(info?.developer, "Square")
        XCTAssertEqual(info?.playCount, 7)
        XCTAssertEqual(info?.isFavorite, true)
        XCTAssertEqual(info?.artworkURLKey, "ct_art")
        XCTAssertNil(source.game(forROMFilename: "missing.sfc"))
        XCTAssertNil(source.game(forROMFilename: ""))
    }

    func testEmptyTitleDerivedFromFilename() {
        let game = LibraryIndexGame(filename: "Some_Game-Name.gba", title: "", systemName: nil, systemIdentifier: nil,
                                    developer: nil, publishDate: nil, genre: nil, gameDescription: nil,
                                    playCount: 0, isFavorite: false, artworkKey: nil)
        _ = LibraryIndexWriter(containerURL: container).write(games: [game], saveStates: [])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        XCTAssertEqual(source.game(forROMFilename: "Some_Game-Name.gba")?.title, "Some Game Name")
    }

    func testSaveStateImageOnlyWhenFileExists() throws {
        let rel = "Documents/Save States/x.jpg"
        let img = container.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: img.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = LibraryIndexWriter(containerURL: container).write(games: [], saveStates: [LibraryIndexSaveState(filename: "x.svs", imageRelativePath: rel)])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        XCTAssertNil(source.saveStateImageURL(forPath: "/any/dir/x.svs"), "index points at a file that does not exist yet")
        try Data([0xFF, 0xD8]).write(to: img)
        XCTAssertEqual(source.saveStateImageURL(forPath: "/any/dir/x.svs"), img)
    }
}
