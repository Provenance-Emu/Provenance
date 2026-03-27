//
//  ROMGameLookupTests.swift
//  PVQuickLookSupportTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVQuickLookSupport

// MARK: - MockGamePreviewDataSource

/// Lightweight in-memory data source used to exercise the `ROMGameLookup`
/// facade without requiring App Groups or a live Realm database.
private struct MockGamePreviewDataSource: GamePreviewDataSource {
    let games: [String: GameInfo]
    let saveStateURLs: [String: URL]

    init(games: [String: GameInfo] = [:], saveStateURLs: [String: URL] = [:]) {
        self.games = games
        self.saveStateURLs = saveStateURLs
    }

    func game(forROMFilename filename: String) -> GameInfo? { games[filename] }
    func saveStateImageURL(forPath path: String) -> URL? { saveStateURLs[path] }
}

final class ROMGameLookupTests: XCTestCase {

    // MARK: - romPathMatches

    func testMatchesSuffixFormat() {
        // romPath stored as "{systemID}/{filename}"
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "SuperMario.sfc")
        )
    }

    func testMatchesExactFormat() {
        // romPath stored as bare filename
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("SuperMario.sfc", filename: "SuperMario.sfc")
        )
    }

    func testDoesNotMatchPartialFilename() {
        // "ario.sfc" is a substring, not the full filename
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "ario.sfc")
        )
    }

    func testDoesNotMatchDifferentFilename() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "Zelda.sfc")
        )
    }

    func testMatchesNestedSubdirectoryPath() {
        // Multi-level path still matches on the trailing component
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("com.provenance.snes/usa/SuperMario.sfc",
                                         filename: "SuperMario.sfc")
        )
    }

    func testEmptyFilenameDoesNotMatch() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "")
        )
    }

    func testEmptyPathDoesNotMatch() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("", filename: "SuperMario.sfc")
        )
    }

    func testBothEmptyDoNotMatch() {
        // Empty filename is always rejected; the predicate guards against it explicitly.
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("", filename: "")
        )
    }

    // MARK: - realFilename(from:)

    func testRealFilenamePassthrough() {
        let url = URL(fileURLWithPath: "/ROMs/SuperMario64.n64")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameStripsIcloudSuffix() {
        // Evicted file without leading dot (edge case)
        let url = URL(fileURLWithPath: "/ROMs/SuperMario64.n64.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameStripsLeadingDotAndIcloudSuffix() {
        // Standard iCloud placeholder: hidden file with leading dot
        let url = URL(fileURLWithPath: "/ROMs/.SuperMario64.n64.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameOnlyIcloudSuffixReturnsEmpty() {
        // Degenerate case: filename is just ".icloud" — returns "" which lookup rejects safely
        let url = URL(fileURLWithPath: "/ROMs/.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "")
    }

    func testRealFilenamePreservesHiddenFileWithoutIcloud() {
        // A legitimately hidden file (dot-prefixed, no .icloud suffix) passes through unchanged
        let url = URL(fileURLWithPath: "/ROMs/.hidden-game.sfc")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), ".hidden-game.sfc")
    }

    // MARK: - lookup (no-database branch)

    func testLookupReturnsNilWhenAppGroupsUnavailable() {
        // In the test process App Groups are not configured, so lookup must
        // return nil gracefully (not crash).
        let result = ROMGameLookup.lookup(forROMFilename: "SuperMario.sfc")
        XCTAssertNil(result, "Expected nil when App Groups are unavailable")
    }

    func testSaveStateImageURLReturnsNilWhenAppGroupsUnavailable() {
        let result = ROMGameLookup.saveStateImageURL(forSaveStatePath: "/some/state.pvsav")
        XCTAssertNil(result, "Expected nil when App Groups are unavailable")
    }

    func testLookupEmptyFilenameReturnsNil() {
        let result = ROMGameLookup.lookup(forROMFilename: "")
        XCTAssertNil(result)
    }

    // MARK: - Mock data source injection

    func testLookupReturnsMockGame() {
        let mockGame = GameInfo(
            title: "Chrono Trigger",
            systemName: "Super Nintendo",
            systemIdentifier: "com.provenance.snes",
            developer: "Square",
            publishDate: "1995",
            genre: "RPG",
            gameDescription: "A classic JRPG.",
            playCount: 7,
            isFavorite: true,
            artworkURLKey: "ct_art"
        )
        let mock = MockGamePreviewDataSource(games: ["ChronoTrigger.sfc": mockGame])
        let original = ROMGameLookup.dataSource
        ROMGameLookup.dataSource = mock
        defer { ROMGameLookup.dataSource = original }

        let result = ROMGameLookup.lookup(forROMFilename: "ChronoTrigger.sfc")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Chrono Trigger")
        XCTAssertEqual(result?.systemName, "Super Nintendo")
        XCTAssertEqual(result?.developer, "Square")
        XCTAssertEqual(result?.playCount, 7)
        XCTAssertEqual(result?.isFavorite, true)
        XCTAssertEqual(result?.artworkURLKey, "ct_art")
    }

    func testLookupMissReturnsNilFromMock() {
        let mock = MockGamePreviewDataSource()
        let original = ROMGameLookup.dataSource
        ROMGameLookup.dataSource = mock
        defer { ROMGameLookup.dataSource = original }

        XCTAssertNil(ROMGameLookup.lookup(forROMFilename: "NotInDB.rom"))
    }

    func testSaveStateImageURLReturnedFromMock() {
        let screenshotURL = URL(fileURLWithPath: "/mnt/screenshots/state.png")
        let mock = MockGamePreviewDataSource(saveStateURLs: ["/saves/state.svs": screenshotURL])
        let original = ROMGameLookup.dataSource
        ROMGameLookup.dataSource = mock
        defer { ROMGameLookup.dataSource = original }

        let result = ROMGameLookup.saveStateImageURL(forSaveStatePath: "/saves/state.svs")
        XCTAssertEqual(result, screenshotURL)
    }

    func testSaveStateImageURLMissReturnsNilFromMock() {
        let mock = MockGamePreviewDataSource()
        let original = ROMGameLookup.dataSource
        ROMGameLookup.dataSource = mock
        defer { ROMGameLookup.dataSource = original }

        XCTAssertNil(ROMGameLookup.saveStateImageURL(forSaveStatePath: "/saves/missing.pvsav"))
    }

    func testDataSourceRestoredAfterMockInjection() {
        // Verify that after injecting a mock and restoring, the original
        // data source is used again (no persistent state leak between tests).
        let original = ROMGameLookup.dataSource
        let mock = MockGamePreviewDataSource(games: ["sentinel.rom": GameInfo(
            title: "Sentinel", systemName: nil, systemIdentifier: nil,
            developer: nil, publishDate: nil, genre: nil, gameDescription: nil,
            playCount: 0, isFavorite: false, artworkURLKey: nil
        )])
        ROMGameLookup.dataSource = mock
        ROMGameLookup.dataSource = original

        // After restoration the mock game should NOT be found
        let result = ROMGameLookup.lookup(forROMFilename: "sentinel.rom")
        // In a test environment the real Realm is unavailable, so nil is expected.
        XCTAssertNil(result, "Real data source should not return the mock game")
    }
}
