//
//  ArtworkMatchingServiceTests.swift
//  PVLibraryTests
//
//  Tests for ArtworkMatchingService — covers the shared fallback-search logic
//  extracted from ArtworkSearchQueue and BatchArtworkMatchingView.
//

import XCTest
@testable import PVLibrary

final class ArtworkMatchingServiceTests: XCTestCase {

    // MARK: - cleanedForArtworkSearch

    func testCleanedForArtworkSearch_removesSquareBrackets() {
        let input = "Sonic the Hedgehog [USA]"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Sonic the Hedgehog")
    }

    func testCleanedForArtworkSearch_removesParentheses() {
        let input = "Mario Kart (Rev A)"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Mario Kart")
    }

    func testCleanedForArtworkSearch_removesCurlyBraces() {
        let input = "Metroid {v1.1}"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Metroid")
    }

    func testCleanedForArtworkSearch_removesMultipleBracketTypes() {
        let input = "Zelda [USA] (Rev 1) {hack}"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Zelda")
    }

    func testCleanedForArtworkSearch_trimsWhitespace() {
        let input = "  Street Fighter II  "
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Street Fighter II")
    }

    func testCleanedForArtworkSearch_preservesHyphenatedTitle() {
        // Word-joining hyphens should survive bracket removal
        let input = "Spider-Man [USA]"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Spider-Man")
    }

    func testCleanedForArtworkSearch_emptyString() {
        XCTAssertEqual("".cleanedForArtworkSearch(), "")
    }

    func testCleanedForArtworkSearch_noTagsUnchanged() {
        let input = "Final Fantasy VII"
        XCTAssertEqual(input.cleanedForArtworkSearch(), input)
    }

    func testCleanedForArtworkSearch_removesIsolatedSpecialChars() {
        // Characters surrounded by spaces should be removed
        let input = "Game , Extra"
        XCTAssertEqual(input.cleanedForArtworkSearch(), "Game Extra")
    }

    // MARK: - ArtworkMatchingService shared instance

    func testSharedInstanceIsNotNil() {
        // Smoke test: the shared actor is accessible
        let service = ArtworkMatchingService.shared
        XCTAssertNotNil(service)
    }

    func testServiceConformsToProtocol() {
        // Compile-time check via typed assignment
        let _: any ArtworkMatchingServiceProtocol = ArtworkMatchingService.shared
    }
}
