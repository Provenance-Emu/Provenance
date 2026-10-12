//
//  FileLocationResolverRootsTests.swift
//  PVLibraryTests
//
//  With a picked folder the library has two roots besides the app-files root: the resolver must search
//  the right one for each partial path and fall back to the app-files root (D10).
//

import XCTest
@testable import PVFileSystem

final class FileLocationResolverRootsTests: XCTestCase {
    private var base = URL(fileURLWithPath: "/")
    private var local = URL(fileURLWithPath: "/")
    private var library = URL(fileURLWithPath: "/")
    private var saves = URL(fileURLWithPath: "/")
    private var cloud = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "FileLocationResolverRootsTests")
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        library = base.appendingPathComponent("picked", isDirectory: true)
        saves = local
        cloud = base.appendingPathComponent("icloud/Documents", isDirectory: true)
        for url in [local, library, cloud] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func resolver(driveMode: Bool = false, library: URL? = nil, saves: URL? = nil) -> FileLocationResolver {
        let local = self.local, lib = library ?? self.library, sav = saves ?? self.saves, cloud = self.cloud
        return FileLocationResolver(localBase: { local }, libraryRoot: { lib }, savesRoot: { sav },
                                    iCloudBase: { cloud }, iCloudDriveMode: { driveMode })
    }

    func testSharedPathsResolveInTheLibraryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Game.sfc"), .local(library.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc")))
    }

    func testSavesResolveInTheSavesRoot() throws {
        try LibraryMoveTestSupport.write(saves, "Save States/Game/s.svs", "save")
        XCTAssertEqual(resolver().resolve("Save States/Game/s.svs"), .local(saves.appendingPathComponent("Save States/Game/s.svs")))
    }

    func testAppFilesRootIsTheFallback() throws {
        // A ROM imported while the picked folder was unavailable landed in Documents; it is still found.
        try LibraryMoveTestSupport.write(local, "ROMs/com.provenance.snes/Old.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Old.sfc"), .local(local.appendingPathComponent("ROMs/com.provenance.snes/Old.sfc")))
    }

    func testLibraryRootWinsOverAppFilesRoot() throws {
        try LibraryMoveTestSupport.write(local, "ROMs/com.provenance.snes/Game.sfc", "old")
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game.sfc", "new")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Game.sfc").url, library.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc"))
    }

    func testDeletedSharedFileIsNotFound() throws {
        // Review Focus 3: another app removed the ROM; nothing elsewhere may stand in for it.
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Gone.sfc"), .notFound)
        XCTAssertFalse(resolver().fileExists("ROMs/com.provenance.snes/Gone.sfc"))
    }

    func testICloudIsSearchedOnlyInDriveMode() throws {
        try LibraryMoveTestSupport.write(cloud, "ROMs/com.provenance.snes/Cloud.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Cloud.sfc"), .notFound)
        XCTAssertEqual(resolver(driveMode: true).resolve("ROMs/com.provenance.snes/Cloud.sfc"), .cloudDrive(cloud.appendingPathComponent("ROMs/com.provenance.snes/Cloud.sfc")))
    }

    func testExpectedURLUsesTheRootForThePath() {
        XCTAssertEqual(resolver().expectedLocalURL(for: "ROMs/x/y.bin"), library.appendingPathComponent("ROMs/x/y.bin"))
        XCTAssertEqual(resolver().expectedLocalURL(for: "Battery States/y/y.sav"), saves.appendingPathComponent("Battery States/y/y.sav"))
        XCTAssertEqual(resolver().bestURL(for: "ROMs/x/missing.bin"), library.appendingPathComponent("ROMs/x/missing.bin"))
    }

    func testSameRootIsSearchedOnce() {
        // App storage: all three roots are Documents. The search order must not repeat it.
        let r = resolver(library: local, saves: local)
        XCTAssertEqual(r.searchBases(for: "ROMs/x").count, 1)
        XCTAssertEqual(resolver().searchBases(for: "ROMs/x").map(\.url), [library, local])
        XCTAssertEqual(resolver().searchBases(for: "Save States/x").map(\.url), [saves])
    }

    func testIndexesCoverEveryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/A.sfc", "a")
        try LibraryMoveTestSupport.write(local, "Save States/A/s.svs", "s")
        let all = resolver().buildLocalFileIndex()
        XCTAssertTrue(all.contains("ROMs/com.provenance.snes/A.sfc"))
        XCTAssertTrue(all.contains("Save States/A/s.svs"))
        let roms = resolver().buildLocalFileIndex(under: "ROMs")
        XCTAssertTrue(roms.contains("ROMs/com.provenance.snes/A.sfc"))
        XCTAssertFalse(roms.contains("Save States/A/s.svs"))
    }

    func testRelativePathStripsTheLibraryRoot() {
        XCTAssertEqual(resolver().relativePath(for: library.appendingPathComponent("ROMs/x/y.bin")), "ROMs/x/y.bin")
        XCTAssertEqual(resolver().relativePath(for: local.appendingPathComponent("Save States/y")), "Save States/y")
        XCTAssertNil(resolver().relativePath(for: base.appendingPathComponent("elsewhere/z")))
    }

    func testFilenameFallbackLooksInTheLibraryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game (USA).sfc", "rom")
        let found = resolver().resolveByFilename(under: "com.provenance.snes", filename: "game (usa).SFC")
        XCTAssertEqual(found.url, library.appendingPathComponent("ROMs/com.provenance.snes/Game (USA).sfc"))
    }
}
