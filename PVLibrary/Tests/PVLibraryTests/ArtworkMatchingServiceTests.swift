//
//  ArtworkMatchingServiceTests.swift
//  PVLibraryTests
//
//  Tests for ArtworkMatchingService — the fast, exact-match artwork lookup
//  that runs at ROM import time before falling back to ArtworkSearchQueue.
//  Also exercises cleanedForArtworkSearch() and shared-instance wiring.
//

import XCTest
import Foundation
import PVLookupTypes
import PVSystems
@testable import PVLibrary

// MARK: - Mock Lookup Provider

/// Mock for ArtworkMatchingLookupProvider. Properties are written before use in tests
/// and read from a single task, so `nonisolated(unsafe)` correctly expresses the intent.
private final class MockArtworkMatchingLookup: ArtworkMatchingLookupProvider, Sendable {
    nonisolated(unsafe) var artworkResults: [ArtworkMetadata]?
    nonisolated(unsafe) var artworkError: Error?
    nonisolated(unsafe) var romMetadata: ROMMetadata?

    func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        if let error = artworkError { throw error }
        return artworkResults
    }

    func getArtwork(forGameID gameID: String, artworkTypes: ArtworkType?) async throws -> [ArtworkMetadata]? {
        return artworkResults
    }

    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        return artworkResults?.map { $0.url }
    }

    func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        return romMetadata
    }
}

/// Mock that returns nil for the first N artwork searches, then returns results.
/// Used to test the MD5 fallback code path.
/// `callCount` is mutated only from a single search task so `nonisolated(unsafe)` is correct.
private final class MockArtworkMatchingLookupCounting: ArtworkMatchingLookupProvider, Sendable {
    nonisolated(unsafe) var romMetadata: ROMMetadata?
    private let firstNilCount: Int
    private let thenResults: [ArtworkMetadata]
    nonisolated(unsafe) private var callCount = 0

    init(firstNilCount: Int, thenResults: [ArtworkMetadata]) {
        self.firstNilCount = firstNilCount
        self.thenResults = thenResults
    }

    func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        defer { callCount += 1 }
        return callCount < firstNilCount ? nil : thenResults
    }

    func getArtwork(forGameID gameID: String, artworkTypes: ArtworkType?) async throws -> [ArtworkMetadata]? {
        return thenResults
    }

    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        return thenResults.map { $0.url }
    }

    func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        return romMetadata
    }
}

// MARK: - ArtworkMatchingServiceTests

final class ArtworkMatchingServiceTests: XCTestCase {

    // MARK: Helpers

    private func makeArtwork(urlString: String, type: ArtworkType = .boxFront) -> ArtworkMetadata {
        ArtworkMetadata(
            url: URL(string: urlString)!,
            type: type,
            source: "mock"
        )
    }

    private func makeROMMetadata(gameTitle: String) -> ROMMetadata {
        ROMMetadata(
            gameTitle: gameTitle,
            systemID: .SNES
        )
    }

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

    // MARK: Happy Path

    func testFindArtwork_returnsURLWhenExactTitleMatches() async {
        let expectedURL = "https://example.com/cover.jpg"
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = [makeArtwork(urlString: expectedURL)]

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Super Mario World", md5: "abc123", systemID: .SNES)

        XCTAssertEqual(result, expectedURL)
    }

    func testFindArtwork_prefersBoxFrontOverOtherTypes() async {
        let screenshotURL = "https://example.com/thumb.jpg"
        let boxFrontURL = "https://example.com/boxfront.jpg"
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = [
            makeArtwork(urlString: screenshotURL, type: .screenshot),
            makeArtwork(urlString: boxFrontURL, type: .boxFront)
        ]

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Some Game", md5: "", systemID: nil)

        XCTAssertEqual(result, boxFrontURL)
    }

    func testFindArtwork_fallsBackToMD5WhenTitleSearchFails() async {
        // First two title searches return nil; MD5 resolves ROM title; 3rd artwork call succeeds.
        let expectedURL = "https://example.com/md5cover.jpg"
        let mock = MockArtworkMatchingLookupCounting(
            firstNilCount: 2,
            thenResults: [makeArtwork(urlString: expectedURL)]
        )
        mock.romMetadata = makeROMMetadata(gameTitle: "Resolved Title")

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Unknown Title", md5: "deadbeef", systemID: .NES)

        XCTAssertEqual(result, expectedURL)
    }

    // MARK: No-Artwork Code Path (no OpenVGDB / multi-source match)

    func testFindArtwork_returnsNilWhenNoResultsFound() async {
        // Simulates the case where neither OpenVGDB nor any other source finds artwork.
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = nil

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Obscure Game Title", md5: "ffffffff", systemID: .SNES)

        XCTAssertNil(result, "Should return nil when no artwork source finds a match")
    }

    func testFindArtwork_returnsNilWhenResultsEmpty() async {
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = []  // Empty array (not nil)

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Some Game", md5: "11223344", systemID: nil)

        XCTAssertNil(result, "Should return nil when artwork search returns empty array")
    }

    func testFindArtwork_returnsNilForWhitespaceOnlyTitle() async {
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = [makeArtwork(urlString: "https://example.com/art.jpg")]

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "   ", md5: "abc", systemID: nil)

        XCTAssertNil(result, "Should return nil for whitespace-only title")
    }

    func testFindArtwork_returnsNilWhenFeatureFlagDisabled() async {
        let previousValue = ENABLE_ENHANCED_ARTWORK_SEARCH
        ENABLE_ENHANCED_ARTWORK_SEARCH = false
        defer { ENABLE_ENHANCED_ARTWORK_SEARCH = previousValue }

        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = [makeArtwork(urlString: "https://example.com/art.jpg")]

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Any Game", md5: "abc", systemID: nil)

        XCTAssertNil(result, "Should return nil when ENABLE_ENHANCED_ARTWORK_SEARCH is false")
    }

    // MARK: Error Handling

    func testFindArtwork_handlesLookupErrorGracefully() async {
        let mock = MockArtworkMatchingLookup()
        mock.artworkError = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])

        let service = ArtworkMatchingService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Error Game", md5: "abc", systemID: .NES)

        XCTAssertNil(result, "Should return nil (not throw) when lookup throws an error")
    }

    // MARK: Performance / Timeout

    func testFindArtwork_completesQuicklyWhenNoArtworkFound() async {
        // Fast lookup returning nil should resolve well under 2s.
        let mock = MockArtworkMatchingLookup()
        mock.artworkResults = nil

        let service = ArtworkMatchingService(lookup: mock)
        let start = Date()
        let result = await service.findArtwork(exactTitle: "Slow Game", md5: "00000000", systemID: nil)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertNil(result)
        XCTAssertLessThan(elapsed, 2.0, "Fast lookup returning nil should not block for 2s")
    }
}
