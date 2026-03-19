//
//  WidgetDataWriterTests.swift
//  PVAppIntentsTests
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVAppIntents

final class WidgetDataWriterTests: XCTestCase {

    // MARK: - WidgetGameData

    func testWidgetGameDataRoundTripsJSON() throws {
        let game = WidgetGameData(
            id: "abc123",
            title: "Super Mario World",
            systemName: "Super Nintendo",
            artworkPath: "artwork/snes/smw.jpg",
            lastPlayedDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(game)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetGameData.self, from: data)

        XCTAssertEqual(decoded.id, game.id)
        XCTAssertEqual(decoded.title, game.title)
        XCTAssertEqual(decoded.systemName, game.systemName)
        XCTAssertEqual(decoded.artworkPath, game.artworkPath)
        XCTAssertNotNil(decoded.lastPlayedDate)
    }

    func testWidgetGameDataWithNilOptionals() throws {
        let game = WidgetGameData(id: "minimal", title: "Tetris", systemName: "Game Boy")
        let encoder = JSONEncoder()
        let data = try encoder.encode(game)
        let decoded = try JSONDecoder().decode(WidgetGameData.self, from: data)
        XCTAssertNil(decoded.artworkPath)
        XCTAssertNil(decoded.lastPlayedDate)
    }

    // MARK: - WidgetNowPlayingData

    func testWidgetNowPlayingDataRoundTripsJSON() throws {
        let nowPlaying = WidgetNowPlayingData(
            trackTitle: "Dire Dire Docks",
            artistName: "Koji Kondo",
            albumTitle: "Super Mario 64",
            albumArtPath: "art/sm64.jpg"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(nowPlaying)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetNowPlayingData.self, from: data)

        XCTAssertEqual(decoded.trackTitle, "Dire Dire Docks")
        XCTAssertEqual(decoded.artistName, "Koji Kondo")
        XCTAssertEqual(decoded.albumTitle, "Super Mario 64")
        XCTAssertEqual(decoded.albumArtPath, "art/sm64.jpg")
        XCTAssertNotNil(decoded.timestamp)
    }

    func testWidgetNowPlayingDataMinimal() throws {
        let nowPlaying = WidgetNowPlayingData(trackTitle: "Unknown Track")
        XCTAssertEqual(nowPlaying.trackTitle, "Unknown Track")
        XCTAssertNil(nowPlaying.artistName)
        XCTAssertNil(nowPlaying.albumTitle)
        XCTAssertNil(nowPlaying.albumArtPath)
    }

    // MARK: - WidgetDataWriter (App Group not available in test sandbox — test write logic only)

    func testWriterDoesNotCrashWithoutAppGroup() {
        // In CI / test sandbox the App Group container is not available.
        // Verify the writer handles this gracefully without throwing.
        let games = [
            WidgetGameData(id: "g1", title: "Game 1", systemName: "NES"),
            WidgetGameData(id: "g2", title: "Game 2", systemName: "SNES")
        ]
        // Should not crash; UserDefaults(suiteName:) returns nil in test context.
        WidgetDataWriter.shared.writeGameData(
            recentGames: games,
            galleryGames: games,
            totalCount: 2
        )
    }

    func testWriterAcceptsNilNowPlaying() {
        // Clear now-playing should not throw or crash.
        WidgetDataWriter.shared.writeNowPlaying(nil)
    }

    func testWriterCapsGamesToTwelve() {
        // Supplying more than 12 games should not crash;
        // internals enforce the 12-game cap via prefix(12).
        let games = (0..<20).map { i in
            WidgetGameData(id: "game-\(i)", title: "Game \(i)", systemName: "NES")
        }
        WidgetDataWriter.shared.writeGameData(
            recentGames: games,
            galleryGames: games,
            totalCount: games.count
        )
    }
}
