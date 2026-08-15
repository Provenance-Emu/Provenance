//
//  LibrarySnapshotTests.swift
//  PVAppIntentsTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVLibrarySnapshot

/// Exercises the read side of the App Group snapshot against a scratch
/// `UserDefaults` suite, so no App Group entitlement is required.
final class LibrarySnapshotTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "org.provenance-emu.tests.snapshot.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeGame(_ id: String, title: String = "Game") -> LibrarySnapshotGame {
        LibrarySnapshotGame(
            id: id,
            title: title,
            systemName: "SNES",
            systemIdentifier: "com.provenance.snes",
            artworkPath: "Documents/PVCache/\(id)",
            lastPlayedDate: Date(timeIntervalSince1970: 1_700_000_000),
            remoteArtworkURL: "https://example.com/\(id).png"
        )
    }

    private func store(_ games: [LibrarySnapshotGame], forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try! encoder.encode(games), forKey: key) // swiftlint:disable:this force_try
    }

    private func writeMinimalSnapshot(version: Int = LibrarySnapshotSchema.currentVersion,
                                      gameCount: Int = 3) {
        defaults.set(version, forKey: LibrarySnapshotKeys.schemaVersion)
        defaults.set(Date().timeIntervalSince1970, forKey: LibrarySnapshotKeys.updatedAt)
        defaults.set(gameCount, forKey: LibrarySnapshotKeys.gameCount)
    }

    // MARK: - Absence

    func testAbsentSnapshotIsUnavailableAndYieldsEmptyLists() {
        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertFalse(reader.isAvailable)
        XCTAssertNil(reader.updatedAt)
        XCTAssertNil(reader.nowPlaying)
        XCTAssertEqual(reader.stats, .empty)
        for list in LibrarySnapshotList.allCases {
            XCTAssertTrue(reader.games(list).isEmpty, "\(list) should be empty")
        }
    }

    func testMissingDefaultsSuiteDegradesToEmpty() {
        let reader = LibrarySnapshotReader(defaults: nil)
        XCTAssertFalse(reader.isAvailable)
        XCTAssertEqual(reader.stats, .empty)
        XCTAssertTrue(reader.games(.recentlyPlayed).isEmpty)
    }

    // MARK: - Round trip

    func testRoundTripPreservesEveryField() {
        writeMinimalSnapshot()
        let original = makeGame("abc123", title: "Chrono Trigger")
        store([original], forKey: LibrarySnapshotKeys.recentGames)

        let decoded = LibrarySnapshotReader(defaults: defaults).games(.recentlyPlayed)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first, original)
        XCTAssertEqual(decoded.first?.md5Hash, "abc123")
    }

    func testEachListReadsItsOwnKey() {
        writeMinimalSnapshot()
        store([makeGame("recent")], forKey: LibrarySnapshotKeys.recentGames)
        store([makeGame("gallery")], forKey: LibrarySnapshotKeys.galleryGames)
        store([makeGame("fav")], forKey: LibrarySnapshotKeys.favoriteGames)
        store([makeGame("added")], forKey: LibrarySnapshotKeys.recentlyAddedGames)

        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertEqual(reader.games(.recentlyPlayed).first?.id, "recent")
        XCTAssertEqual(reader.games(.gallery).first?.id, "gallery")
        XCTAssertEqual(reader.games(.favorites).first?.id, "fav")
        XCTAssertEqual(reader.games(.recentlyAdded).first?.id, "added")
    }

    func testLimitCapsResults() {
        writeMinimalSnapshot()
        store((0..<10).map { makeGame("g\($0)") }, forKey: LibrarySnapshotKeys.recentGames)

        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertEqual(reader.games(.recentlyPlayed, limit: 4).count, 4)
        XCTAssertEqual(reader.games(.recentlyPlayed, limit: 0).count, 0)
        XCTAssertEqual(reader.games(.recentlyPlayed, limit: 100).count, 10)
    }

    func testCorruptPayloadYieldsEmptyRatherThanThrowing() {
        writeMinimalSnapshot()
        defaults.set(Data("not json".utf8), forKey: LibrarySnapshotKeys.recentGames)
        XCTAssertTrue(LibrarySnapshotReader(defaults: defaults).games(.recentlyPlayed).isEmpty)
    }

    // MARK: - Versioning

    func testUnversionedLegacyDataIsStillReadable() {
        // A build predating versioning wrote lists and counts but no version key.
        defaults.set(2, forKey: LibrarySnapshotKeys.gameCount)
        store([makeGame("legacy")], forKey: LibrarySnapshotKeys.recentGames)

        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertEqual(reader.schemaVersion, LibrarySnapshotSchema.unversioned)
        XCTAssertTrue(reader.isSchemaSupported)
        XCTAssertTrue(reader.isAvailable)
        XCTAssertEqual(reader.games(.recentlyPlayed).first?.id, "legacy")
        // A list added after v0 is simply absent, not an error.
        XCTAssertTrue(reader.games(.recentlyAdded).isEmpty)
    }

    func testFutureSchemaVersionIsRejectedWithoutTrapping() {
        writeMinimalSnapshot(version: LibrarySnapshotSchema.currentVersion + 1)
        store([makeGame("future")], forKey: LibrarySnapshotKeys.recentGames)

        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertFalse(reader.isSchemaSupported)
        XCTAssertFalse(reader.isAvailable)
        XCTAssertEqual(reader.stats, .empty)
        XCTAssertTrue(reader.games(.recentlyPlayed).isEmpty)
    }

    func testEmptyLibraryIsNotReportedAvailable() {
        writeMinimalSnapshot(gameCount: 0)
        XCTAssertFalse(LibrarySnapshotReader(defaults: defaults).isAvailable)
    }

    // MARK: - Staleness

    func testStalenessUsesWriteTimestamp() {
        defaults.set(LibrarySnapshotSchema.currentVersion, forKey: LibrarySnapshotKeys.schemaVersion)
        defaults.set(Date().addingTimeInterval(-3600).timeIntervalSince1970,
                     forKey: LibrarySnapshotKeys.updatedAt)

        let reader = LibrarySnapshotReader(defaults: defaults)
        XCTAssertTrue(reader.isStale(olderThan: 60))
        XCTAssertFalse(reader.isStale(olderThan: 7200))
    }

    func testSnapshotWithoutTimestampIsNotConsideredStale() {
        defaults.set(5, forKey: LibrarySnapshotKeys.gameCount)
        XCTAssertFalse(LibrarySnapshotReader(defaults: defaults).isStale(olderThan: 1))
    }

    // MARK: - Stats

    func testStatsReadAllCounters() {
        writeMinimalSnapshot(gameCount: 42)
        defaults.set(7, forKey: LibrarySnapshotKeys.systemCount)
        defaults.set(3600, forKey: LibrarySnapshotKeys.totalPlayTime)
        defaults.set(5, forKey: LibrarySnapshotKeys.favoritesCount)

        XCTAssertEqual(
            LibrarySnapshotReader(defaults: defaults).stats,
            LibrarySnapshotStats(totalGames: 42, totalSystems: 7,
                                 totalPlayTimeSeconds: 3600, favoritesCount: 5)
        )
    }

    // MARK: - Artwork resolution

    func testBestArtworkURLFallsBackToRemoteWhenNoLocalFile() {
        let game = makeGame("nofile")
        // The relative path resolves inside the App Group container, which does
        // not exist in the test sandbox, so the remote URL must win.
        XCTAssertEqual(game.bestArtworkURL?.scheme, "https")
    }

    func testBestArtworkURLIsNilWithNoArtworkAtAll() {
        let game = LibrarySnapshotGame(id: "x", title: "X", systemName: "S")
        XCTAssertNil(game.bestArtworkURL)
        XCTAssertNil(game.localArtworkURL)
    }

    func testEmptyRelativePathDoesNotResolve() {
        XCTAssertNil(LibrarySnapshotAppGroup.url(forRelativePath: ""))
    }

    // MARK: - Now playing

    func testNowPlayingRoundTrip() {
        writeMinimalSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let track = LibrarySnapshotNowPlaying(trackTitle: "Aquatic Ambiance", artistName: "David Wise")
        defaults.set(try! encoder.encode(track), forKey: LibrarySnapshotKeys.nowPlaying) // swiftlint:disable:this force_try

        let decoded = LibrarySnapshotReader(defaults: defaults).nowPlaying
        XCTAssertEqual(decoded?.trackTitle, "Aquatic Ambiance")
        XCTAssertEqual(decoded?.artistName, "David Wise")
        XCTAssertNil(decoded?.albumTitle)
    }
}

/// Guards the shape table used by Top Shelf to pick `ImageShape`.
final class LibraryArtworkShapeTests: XCTestCase {
    func testWideSystemsResolveToWide() {
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.snes"), .wide)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.psx"), .wide)
    }

    func testHandheldsAndUnknownsResolveToSquare() {
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.gb"), .square)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.example.unknown"), .square)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: nil), .square)
    }

    func testEveryWideIdentifierUsesTheProvenanceReverseDNSPrefix() {
        // Cheap guard against a typo'd entry silently never matching.
        for identifier in ["com.provenance.snes", "com.provenance.wii"] {
            XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: identifier), .wide)
        }
    }
}
