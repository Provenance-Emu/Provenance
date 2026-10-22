//
//  ProvenanceSnapshotTests.swift
//  PVLibrarySnapshotConfigTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVLibrarySnapshotConfig

final class ProvenanceSnapshotConfigurationTests: XCTestCase {
    func testLaunchURLMatchesTheAppDeepLink() {
        let game = ProvenanceSnapshotBuilder.game(from: .fixture(md5: "C2B7BA0303A8E19B218F517D8B6FA487"), coverFilename: nil)
        XCTAssertEqual(game.launchURL?.absoluteString, "provenance://open?md5=C2B7BA0303A8E19B218F517D8B6FA487")
    }

    func testAppGroupComesFromInfoPlistValue() {
        XCTAssertEqual(ProvenanceSnapshot.resolveAppGroupIdentifier("group.com.example.sideload"), "group.com.example.sideload")
    }

    func testMissingOrUnexpandedAppGroupFallsBack() {
        let fallback = ProvenanceSnapshot.fallbackAppGroupIdentifier
        XCTAssertEqual(ProvenanceSnapshot.resolveAppGroupIdentifier(nil), fallback)
        XCTAssertEqual(ProvenanceSnapshot.resolveAppGroupIdentifier(""), fallback)
        XCTAssertEqual(ProvenanceSnapshot.resolveAppGroupIdentifier("$(APP_GROUP_IDENTIFIER)"), fallback)
    }

    func testCoversLiveUnderLibraryCaches() {
        // tvOS only allows writes under Library/Caches in a group container.
        XCTAssertTrue(ProvenanceSnapshot.configuration.mediaSubpath.hasPrefix("Library/Caches/"))
    }
}

final class ProvenanceSnapshotBuilderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUnplayedGamesStayOutOfRecentlyPlayed() {
        let snapshot = ProvenanceSnapshotBuilder.snapshot(from: [
            .fixture(md5: "PLAYED", lastPlayed: now),
            .fixture(md5: "NEVER", lastPlayed: nil)
        ], covers: [:], now: now)
        XCTAssertEqual(snapshot.recentlyPlayed.map(\.id), ["PLAYED"])
    }

    func testRecentlyAddedFollowsImportDate() {
        let snapshot = ProvenanceSnapshotBuilder.snapshot(from: [
            .fixture(md5: "OLD", importDate: now.addingTimeInterval(-100)),
            .fixture(md5: "NEW", importDate: now)
        ], covers: [:], now: now)
        XCTAssertEqual(snapshot.recentlyAdded.map(\.id), ["NEW", "OLD"])
    }

    func testFieldsMapOntoTheSharedGame() {
        let source = ProvenanceSnapshotSource.fixture(md5: "ABC", isFavorite: true, importDate: now)
        let snapshot = ProvenanceSnapshotBuilder.snapshot(from: [source], covers: ["ABC": "cover_ABC_1.jpg"], now: now)
        let game = snapshot.game(id: "ABC")
        XCTAssertEqual(game?.title, source.title)
        XCTAssertEqual(game?.filePath, source.romPath)
        XCTAssertEqual(game?.platform, source.systemIdentifier)
        XCTAssertEqual(game?.region, source.regionName)
        XCTAssertEqual(game?.dateAdded, now)
        XCTAssertEqual(game?.coverFilename, "cover_ABC_1.jpg")
        XCTAssertEqual(snapshot.favorites.map(\.id), ["ABC"])
    }

    func testGamesWithoutAMirroredCoverHaveNoCoverFilename() {
        let snapshot = ProvenanceSnapshotBuilder.snapshot(from: [.fixture(md5: "ABC")], covers: [:], now: now)
        XCTAssertNil(snapshot.game(id: "ABC")?.coverFilename)
    }

    func testCoverFilenameChangesWithTheArtworkKey() {
        let original = ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "https://example.com/a.png")
        let custom = ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "artwork_ABC_1.png")
        XCTAssertNotEqual(original, custom)
        XCTAssertEqual(original, ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "https://example.com/a.png"))
        XCTAssertTrue(original.hasPrefix(ProvenanceSnapshotBuilder.coverFilenamePrefix + "ABC_"))
        XCTAssertTrue(original.hasSuffix(".jpg"))
    }

    func testStableHashIsFNV1a() {
        // Published FNV-1a 64 test vectors.
        XCTAssertEqual(ProvenanceSnapshotBuilder.stableHash(""), "cbf29ce484222325")
        XCTAssertEqual(ProvenanceSnapshotBuilder.stableHash("a"), "af63dc4c8601ec8c")
    }

    func testLastPlayedTakesTheNewestDateAndStaysNilWhenUnplayed() {
        let older = now.addingTimeInterval(-60)
        XCTAssertEqual(ProvenanceSnapshotBuilder.lastPlayed(recent: older, game: now), now)
        XCTAssertEqual(ProvenanceSnapshotBuilder.lastPlayed(recent: now, game: nil), now)
        XCTAssertNil(ProvenanceSnapshotBuilder.lastPlayed(recent: nil, game: nil))
    }
}

private extension ProvenanceSnapshotSource {
    static func fixture(md5: String, lastPlayed: Date? = nil, isFavorite: Bool = false,
                        importDate: Date? = nil) -> ProvenanceSnapshotSource {
        ProvenanceSnapshotSource(md5: md5, title: "Game \(md5)", romPath: "ROMs/\(md5).sfc",
                                 systemIdentifier: "com.provenance.snes", regionName: "USA",
                                 lastPlayed: lastPlayed, isFavorite: isFavorite,
                                 importDate: importDate, artworkKey: nil)
    }
}
