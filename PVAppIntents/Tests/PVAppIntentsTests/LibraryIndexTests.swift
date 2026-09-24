import XCTest
@testable import PVLibrarySnapshot

final class LibraryIndexTests: XCTestCase {
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

    private let smw = LibraryIndexGame(filename: "Super Mario World.sfc", title: "Super Mario World",
                                       systemName: "Super Nintendo", systemIdentifier: "com.provenance.snes",
                                       developer: "Nintendo", publishDate: "1990", genre: "Platformer",
                                       gameDescription: "Yoshi debuts.", playCount: 3, isFavorite: true,
                                       artworkKey: "https://example.com/smw.jpg")

    func testWriteThenReadGame() throws {
        let writer = LibraryIndexWriter(containerURL: container)
        XCTAssertTrue(writer.write(games: [smw], saveStates: [LibraryIndexSaveState(filename: "smw.svs", imageRelativePath: "Documents/Save States/smw.jpg")]))
        let reader = LibraryIndexReader(containerURL: container)
        let g = reader.game(forROMFilename: "Super Mario World.sfc")
        XCTAssertEqual(g?.title, "Super Mario World")
        XCTAssertEqual(g?.playCount, 3)
        XCTAssertEqual(g?.artworkKey, "https://example.com/smw.jpg")
        XCTAssertNil(reader.game(forROMFilename: "nope.sfc"))
        XCTAssertEqual(reader.saveStateImageURL(forFilename: "smw.svs"), container.appendingPathComponent("Documents/Save States/smw.jpg"))
        XCTAssertNil(reader.saveStateImageURL(forFilename: "other.svs"))
    }

    func testFilesLandUnderLibraryCaches() {
        _ = LibraryIndexWriter(containerURL: container).write(games: [smw], saveStates: [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent(LibraryIndexPaths.games).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent(LibraryIndexPaths.saveStates).path))
    }

    func testMissingFilesReadAsEmpty() {
        let reader = LibraryIndexReader(containerURL: container)
        XCTAssertNil(reader.game(forROMFilename: "x.sfc"))
        XCTAssertNil(reader.saveStateImageURL(forFilename: "x.svs"))
    }

    func testCorruptFileReadsAsEmpty() throws {
        let url = container.appendingPathComponent(LibraryIndexPaths.games)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        XCTAssertNil(LibraryIndexReader(containerURL: container).game(forROMFilename: "x.sfc"))
    }

    func testNilContainerIsInert() {
        XCTAssertFalse(LibraryIndexWriter(containerURL: nil).write(games: [smw], saveStates: []))
        XCTAssertNil(LibraryIndexReader(containerURL: nil).game(forROMFilename: "Super Mario World.sfc"))
    }

    func testDuplicateFilenamesKeepFirst() {
        var second = smw
        second = LibraryIndexGame(filename: smw.filename, title: "Other", systemName: "X", systemIdentifier: nil,
                                  developer: nil, publishDate: nil, genre: nil, gameDescription: nil,
                                  playCount: 0, isFavorite: false, artworkKey: nil)
        _ = LibraryIndexWriter(containerURL: container).write(games: [smw, second], saveStates: [])
        XCTAssertEqual(LibraryIndexReader(containerURL: container).game(forROMFilename: smw.filename)?.title, "Super Mario World")
    }
}
