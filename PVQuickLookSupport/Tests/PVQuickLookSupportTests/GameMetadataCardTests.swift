//
//  GameMetadataCardTests.swift
//  PVQuickLookSupportTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVQuickLookSupport

final class GameMetadataCardTests: XCTestCase {

    // MARK: - HTML structure

    func testHTMLContainsDoctype() {
        let html = GameMetadataCard.html(for: nil, filename: "test.rom")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }

    func testHTMLContainsFilename() {
        let html = GameMetadataCard.html(for: nil, filename: "SuperMario.sfc")
        XCTAssertTrue(html.contains("SuperMario.sfc"))
    }

    func testHTMLContainsDerivedTitleWhenNoGameInfo() {
        // Without GameInfo the filename (minus extension) is used as title.
        let html = GameMetadataCard.html(for: nil, filename: "Super_Mario.sfc")
        XCTAssertTrue(html.contains("Super Mario"))
    }

    func testHTMLContainsGameTitle() {
        let info = makeGameInfo(title: "Super Mario World")
        let html = GameMetadataCard.html(for: info, filename: "smw.sfc")
        XCTAssertTrue(html.contains("Super Mario World"))
    }

    func testHTMLContainsSystemName() {
        let info = makeGameInfo(systemName: "Super Nintendo")
        let html = GameMetadataCard.html(for: info, filename: "smw.sfc")
        XCTAssertTrue(html.contains("Super Nintendo"))
    }

    func testHTMLEscapesSpecialCharacters() {
        let info = makeGameInfo(title: "Simon & Garfunkel <Greatest> \"Hits\"")
        let html = GameMetadataCard.html(for: info, filename: "test.rom")
        XCTAssertTrue(html.contains("Simon &amp; Garfunkel &lt;Greatest&gt; &quot;Hits&quot;"))
        XCTAssertFalse(html.contains("<Greatest>"))
    }

    func testHTMLContainsFavoriteBadgeWhenFavorite() {
        let info = makeGameInfo(isFavorite: true)
        let html = GameMetadataCard.html(for: info, filename: "test.rom")
        XCTAssertTrue(html.contains("Favorite"))
    }

    func testHTMLDoesNotContainFavoriteBadgeWhenNotFavorite() {
        let info = makeGameInfo(isFavorite: false)
        let html = GameMetadataCard.html(for: info, filename: "test.rom")
        XCTAssertFalse(html.contains("favorite\">★"))
    }

    func testHTMLContainsPlayCount() {
        let info = makeGameInfo(playCount: 42)
        let html = GameMetadataCard.html(for: info, filename: "test.rom")
        XCTAssertTrue(html.contains("42 plays"))
    }

    func testHTMLSingularPlayCount() {
        let info = makeGameInfo(playCount: 1)
        let html = GameMetadataCard.html(for: info, filename: "test.rom")
        XCTAssertTrue(html.contains("1 play") && !html.contains("1 plays"))
    }

    func testHTMLContainsArtworkTagWhenDataProvided() {
        let fakeJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG magic bytes
        let info = makeGameInfo()
        let html = GameMetadataCard.html(for: info, filename: "test.rom", artworkData: fakeJPEG)
        XCTAssertTrue(html.contains("data:image/jpeg;base64,"))
    }

    func testHTMLContainsPNGTagWhenPNGDataProvided() {
        // PNG magic bytes: 89 50 4E 47
        let fakePNG = Data([0x89, 0x50, 0x4E, 0x47])
        let info = makeGameInfo()
        let html = GameMetadataCard.html(for: info, filename: "test.rom", artworkData: fakePNG)
        XCTAssertTrue(html.contains("data:image/png;base64,"))
    }

    func testHTMLContainsPlaceholderWhenNoArtwork() {
        let info = makeGameInfo()
        let html = GameMetadataCard.html(for: info, filename: "test.rom", artworkData: nil)
        XCTAssertTrue(html.contains("art-placeholder"))
    }

    // MARK: - Helpers

    private func makeGameInfo(
        title: String = "Test Game",
        systemName: String? = "Test System",
        systemIdentifier: String? = "com.provenance.test",
        developer: String? = "Test Dev",
        publishDate: String? = "1996",
        genre: String? = "Action",
        gameDescription: String? = nil,
        playCount: Int = 0,
        isFavorite: Bool = false
    ) -> GameInfo {
        GameInfo(
            title: title,
            systemName: systemName,
            systemIdentifier: systemIdentifier,
            developer: developer,
            publishDate: publishDate,
            genre: genre,
            gameDescription: gameDescription,
            playCount: playCount,
            isFavorite: isFavorite,
            artworkURLKey: nil
        )
    }
}
