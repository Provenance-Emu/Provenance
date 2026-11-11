import XCTest
@testable import PVLibrary

/// The tvOS database leaves the App Group container; `moveDatabase` is the file step.
final class RealmDatabaseRelocationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ relativePath: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func contents(of url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    func testMovesTheDatabaseIntoAFolderThatDoesNotExistYet() throws {
        let source = try makeFile("group/default.realm", contents: "group")
        let destination = root.appendingPathComponent("caches/Database/default.realm")

        XCTAssertEqual(RealmConfiguration.moveDatabase(from: [source], to: destination), source)

        XCTAssertEqual(try contents(of: destination), "group")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testPrefersTheFirstSourceThatExists() throws {
        let missing = root.appendingPathComponent("group/default.realm")
        let legacy = try makeFile("documents/default.realm", contents: "legacy")
        let destination = root.appendingPathComponent("caches/Database/default.realm")

        XCTAssertEqual(RealmConfiguration.moveDatabase(from: [missing, legacy], to: destination), legacy)
        XCTAssertEqual(try contents(of: destination), "legacy")
    }

    func testTakesOnlyTheFirstSourceWhenBothExist() throws {
        let group = try makeFile("group/default.realm", contents: "group")
        let legacy = try makeFile("documents/default.realm", contents: "legacy")
        let destination = root.appendingPathComponent("caches/Database/default.realm")

        RealmConfiguration.moveDatabase(from: [group, legacy], to: destination)

        XCTAssertEqual(try contents(of: destination), "group")
        XCTAssertEqual(try contents(of: legacy), "legacy")
    }

    func testNeverReplacesADatabaseAlreadyAtTheDestination() throws {
        let source = try makeFile("group/default.realm", contents: "group")
        let destination = try makeFile("caches/Database/default.realm", contents: "current")

        XCTAssertNil(RealmConfiguration.moveDatabase(from: [source], to: destination))

        XCTAssertEqual(try contents(of: destination), "current")
        XCTAssertEqual(try contents(of: source), "group")
    }

    func testLeavesRealmSideFilesBehind() throws {
        let source = try makeFile("group/default.realm", contents: "group")
        let lock = try makeFile("group/default.realm.lock", contents: "lock")
        let destination = root.appendingPathComponent("caches/Database/default.realm")

        RealmConfiguration.moveDatabase(from: [source], to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: lock.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path + ".lock"))
    }

    func testDoesNothingWithoutAnySource() {
        let destination = root.appendingPathComponent("caches/Database/default.realm")
        XCTAssertNil(RealmConfiguration.moveDatabase(from: [root.appendingPathComponent("none.realm")], to: destination))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}
