//
//  ArtworkMatchingServiceTests.swift
//  PVLibraryTests
//
//  Tests for FastArtworkLookupService — the fast, exact-match artwork lookup
//  that runs at ROM import time before falling back to ArtworkSearchQueue.
//  Also exercises cleanedForArtworkSearch(), shared-instance wiring, and
//  multi-type artwork saving logic in ArtworkSearchQueue.
//

import XCTest
import Foundation
import PVLookupTypes
import PVSystems
@testable import PVLibrary

// MARK: - Mock service

/// Deterministic mock that returns a configurable list of ArtworkMetadata items.
/// Implemented as an actor so concurrent calls from `ArtworkSearchQueue` are
/// serialised without needing a manual lock or `@unchecked Sendable`.
actor MockArtworkMatchingService: ArtworkMatchingServiceProtocol {

    /// Results returned regardless of input parameters.
    var stubbedResults: [ArtworkMetadata] = []

    /// Records every call so tests can assert on parameters.
    private(set) var calls: [(title: String, artworkTypes: ArtworkType)] = []

    /// Convenience setter for test setup — required because actor-isolated stored
    /// properties cannot be mutated from outside the actor without `await`.
    func configure(stubbedResults: [ArtworkMetadata]) {
        self.stubbedResults = stubbedResults
    }

    func findArtwork(
        title: String,
        filename: String?,
        md5: String?,
        systemIdentifier: SystemIdentifier?,
        artworkTypes: ArtworkType
    ) async -> [ArtworkMetadata] {
        calls.append((title: title, artworkTypes: artworkTypes))
        return stubbedResults
    }
}

// MARK: - ArtworkMatchingService unit tests

// MARK: - Mock Lookup Provider

/// Simple actor-based mock for ArtworkMatchingLookupProvider (used by FastArtworkLookupService).
/// Using an actor ensures mutable state is safely accessed under concurrency checking.
private actor MockArtworkMatchingLookup: ArtworkMatchingLookupProvider {
    var artworkResults: [ArtworkMetadata]?
    var artworkError: Error?
    var romMetadata: ROMMetadata?

    init(artworkResults: [ArtworkMetadata]? = nil, artworkError: Error? = nil, romMetadata: ROMMetadata? = nil) {
        self.artworkResults = artworkResults
        self.artworkError = artworkError
        self.romMetadata = romMetadata
    }

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

/// Actor-based mock that returns nil for the first N artwork searches, then returns results.
/// Used to test the MD5 fallback code path.
private actor MockArtworkMatchingLookupCounting: ArtworkMatchingLookupProvider {
    var romMetadata: ROMMetadata?
    private let firstNilCount: Int
    private let thenResults: [ArtworkMetadata]
    private var callCount = 0

    init(firstNilCount: Int, thenResults: [ArtworkMetadata], romMetadata: ROMMetadata? = nil) {
        self.firstNilCount = firstNilCount
        self.thenResults = thenResults
        self.romMetadata = romMetadata
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

/// Suspends until the test supplies a result or the service cancels the lookup.
private actor MockArtworkMatchingLookupSuspended: ArtworkMatchingLookupProvider {
    private let started: XCTestExpectation
    private let results: AsyncStream<[ArtworkMetadata]?>
    private let continuation: AsyncStream<[ArtworkMetadata]?>.Continuation
    private(set) var cancellationObserved = false
    private(set) var searchCount = 0

    init(started: XCTestExpectation) {
        self.started = started
        let pair = AsyncStream<[ArtworkMetadata]?>.makeStream()
        results = pair.stream
        continuation = pair.continuation
    }

    func finish(with result: [ArtworkMetadata]? = nil) {
        continuation.yield(result)
        continuation.finish()
    }

    func searchArtwork(byGameName name: String, systemID: SystemIdentifier?, artworkTypes: ArtworkType?) async throws -> [ArtworkMetadata]? {
        searchCount += 1
        started.fulfill()
        var iterator = results.makeAsyncIterator()
        let result = await iterator.next()
        do {
            try Task.checkCancellation()
        } catch {
            cancellationObserved = true
            throw error
        }
        return result ?? nil
    }

    func getArtwork(forGameID gameID: String, artworkTypes: ArtworkType?) async throws -> [ArtworkMetadata]? { nil }
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? { nil }
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata? { nil }
}

/// A manually fired timer. No sub-second wall-clock assertion depends on CI load.
private actor ManualArtworkTimeout {
    private let scheduled: XCTestExpectation
    private let ticks: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private(set) var requestedNanoseconds: UInt64?
    private(set) var cancellationObserved = false

    init(scheduled: XCTestExpectation) {
        self.scheduled = scheduled
        let pair = AsyncStream<Void>.makeStream()
        ticks = pair.stream
        continuation = pair.continuation
    }

    func sleep(nanoseconds: UInt64) async throws {
        requestedNanoseconds = nanoseconds
        scheduled.fulfill()
        var iterator = ticks.makeAsyncIterator()
        _ = await iterator.next()
        do {
            try Task.checkCancellation()
        } catch {
            cancellationObserved = true
            throw error
        }
    }

    func fire() {
        continuation.yield(())
        continuation.finish()
    }
}

// MARK: - ArtworkMatchingServiceTests

final class ArtworkMatchingServiceTests: XCTestCase {

    // MARK: setUp / tearDown

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

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

    // MARK: - artworkSearchCleaned / cleanedForArtworkSearch

    func test_cleanedTitle_stripsSquareBrackets() {
        let raw = "Super Mario Bros. [USA]"
        XCTAssertEqual(raw.artworkSearchCleaned(), "Super Mario Bros.")
    }

    func test_cleanedTitle_stripsParentheses() {
        let raw = "Sonic (Rev A)"
        XCTAssertEqual(raw.artworkSearchCleaned(), "Sonic")
    }

    func test_cleanedTitle_stripsCurlyBraces() {
        let raw = "Game {Hack}"
        XCTAssertEqual(raw.artworkSearchCleaned(), "Game")
    }

    func test_cleanedTitle_trimsWhitespace() {
        let raw = "  Castlevania  "
        XCTAssertEqual(raw.artworkSearchCleaned(), "Castlevania")
    }

    func test_cleanedTitle_preservesTitleWithNoTags() {
        let raw = "Metroid"
        XCTAssertEqual(raw.artworkSearchCleaned(), "Metroid")
    }

    // MARK: ArtworkMatchingService (unit, no network)

    /// Validates that the mock correctly returns stubbed results and records call parameters.
    func test_mockService_returnsBoxFrontAndBoxBack() async {
        let mock = MockArtworkMatchingService()
        await mock.configure(stubbedResults: [
            ArtworkMetadata(
                url: URL(string: "https://example.com/front.jpg")!,
                type: .boxFront,
                source: "TheGamesDB"
            ),
            ArtworkMetadata(
                url: URL(string: "https://example.com/back.jpg")!,
                type: .boxBack,
                source: "TheGamesDB"
            )
        ])

        let requestedTypes: ArtworkType = [.boxFront, .boxBack]
        let results = await mock.findArtwork(
            title: "Zelda",
            filename: "Zelda",
            md5: nil,
            systemIdentifier: .NES,
            artworkTypes: requestedTypes
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.type == .boxFront })
        XCTAssertTrue(results.contains { $0.type == .boxBack })
        // Verify call was recorded with correct parameters
        let calls = await mock.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.title, "Zelda")
        XCTAssertEqual(calls.first?.artworkTypes, requestedTypes)
    }

    func test_mockService_emptyResultsWhenNoneStubbed() async {
        let mock = MockArtworkMatchingService()
        await mock.configure(stubbedResults: [])

        let results = await mock.findArtwork(
            title: "Unknown Game",
            filename: nil,
            md5: nil,
            systemIdentifier: nil,
            artworkTypes: .defaults
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: ArtworkSearchQueue integration (mock service)

    func test_queuePassesPrimaryArtworkTypesToService() async {
        let mock = MockArtworkMatchingService()
        await mock.configure(stubbedResults: [])

        let queue = ArtworkSearchQueue(matchingService: mock)
        await queue.queueGameForArtworkSearch(
            gameID: "test-id",
            title: "Test Game",
            filename: "TestGame",
            systemID: .SNES,
            md5Hash: "abcdef1234567890"
        )
        // Force processing of pending searches immediately (bypasses debounce delay)
        await queue.processPendingSearches()

        // The queue should have called findArtwork with [.boxFront, .boxBack]
        let calls = await mock.calls
        XCTAssertFalse(calls.isEmpty, "Expected at least one findArtwork call")
        let primaryTypes: ArtworkType = [.boxFront, .boxBack]
        XCTAssertTrue(
            calls.contains { $0.artworkTypes == primaryTypes },
            "Expected primary types \(primaryTypes) in calls \(calls.map { $0.artworkTypes })"
        )
    }

    func testCleanedForArtworkSearch_removesIsolatedSpecialChars() {
        // Characters surrounded by spaces should be removed
        let input = "Game , Extra"
        XCTAssertEqual(input.artworkSearchCleaned(), "Game Extra")
    }

    func test_boxBackMetadataURL_isValidURL() {
        // Verify that ArtworkMetadata with a boxBack type carries a proper URL
        let urlString = "https://cdn.thegamesdb.net/images/back/12345.jpg"
        let metadata = ArtworkMetadata(
            url: URL(string: urlString)!,
            type: .boxBack,
            source: "TheGamesDB"
        )
        XCTAssertEqual(metadata.type, .boxBack)
        XCTAssertEqual(metadata.url.absoluteString, urlString)
        XCTAssertEqual(metadata.source, "TheGamesDB")
    }

    // MARK: - Shared instance smoke tests

    func testArtworkMatchingServiceSharedInstanceIsNotNil() {
        // ArtworkMatchingService (progressive fallback, used by ArtworkSearchQueue)
        let service = ArtworkMatchingService.shared
        XCTAssertNotNil(service)
    }

    func testArtworkMatchingServiceConformsToProtocol() {
        // Compile-time check: ArtworkMatchingService must satisfy ArtworkMatchingServiceProtocol
        let _: any ArtworkMatchingServiceProtocol = ArtworkMatchingService.shared
    }

    func testFastArtworkLookupServiceSharedInstanceIsNotNil() {
        // FastArtworkLookupService (import-time exact match)
        let service = FastArtworkLookupService.shared
        XCTAssertNotNil(service)
    }

    // MARK: Happy Path

    func testFindArtwork_returnsURLWhenExactTitleMatches() async {
        let expectedURL = "https://example.com/cover.jpg"
        let mock = MockArtworkMatchingLookup(artworkResults: [makeArtwork(urlString: expectedURL)])

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Super Mario World", md5: "abc123", systemID: .SNES)

        XCTAssertEqual(result, expectedURL)
    }

    func testFindArtwork_prefersBoxFrontOverOtherTypes() async {
        let screenshotURL = "https://example.com/thumb.jpg"
        let boxFrontURL = "https://example.com/boxfront.jpg"
        let mock = MockArtworkMatchingLookup(artworkResults: [
            makeArtwork(urlString: screenshotURL, type: .screenshot),
            makeArtwork(urlString: boxFrontURL, type: .boxFront)
        ])

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Some Game", md5: "", systemID: nil)

        XCTAssertEqual(result, boxFrontURL)
    }

    func testFindArtwork_fallsBackToMD5WhenTitleSearchFails() async {
        // First two title searches return nil; MD5 resolves ROM title; 3rd artwork call succeeds.
        let expectedURL = "https://example.com/md5cover.jpg"
        let mock = MockArtworkMatchingLookupCounting(
            firstNilCount: 2,
            thenResults: [makeArtwork(urlString: expectedURL)],
            romMetadata: makeROMMetadata(gameTitle: "Resolved Title")
        )

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Unknown Title", md5: "deadbeef", systemID: .NES)

        XCTAssertEqual(result, expectedURL)
    }

    // MARK: No-Artwork Code Path (no OpenVGDB / multi-source match)

    func testFindArtwork_returnsNilWhenNoResultsFound() async {
        // Simulates the case where neither OpenVGDB nor any other source finds artwork.
        let mock = MockArtworkMatchingLookup()

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Obscure Game Title", md5: "ffffffff", systemID: .SNES)

        XCTAssertNil(result, "Should return nil when no artwork source finds a match")
    }

    func testFindArtwork_returnsNilWhenResultsEmpty() async {
        let mock = MockArtworkMatchingLookup(artworkResults: [])

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Some Game", md5: "11223344", systemID: nil)

        XCTAssertNil(result, "Should return nil when artwork search returns empty array")
    }

    func testFindArtwork_returnsNilForWhitespaceOnlyTitle() async {
        let mock = MockArtworkMatchingLookup(artworkResults: [makeArtwork(urlString: "https://example.com/art.jpg")])

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "   ", md5: "abc", systemID: nil)

        XCTAssertNil(result, "Should return nil for whitespace-only title")
    }

    // MARK: Error Handling

    func testFindArtwork_handlesLookupErrorGracefully() async {
        let mock = MockArtworkMatchingLookup(artworkError: NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"]))

        let service = FastArtworkLookupService(lookup: mock)
        let result = await service.findArtwork(exactTitle: "Error Game", md5: "abc", systemID: .NES)

        XCTAssertNil(result, "Should return nil (not throw) when lookup throws an error")
    }

    // MARK: Performance / Timeout

    func testFindArtwork_completesQuicklyWhenNoArtworkFound() async {
        // Fast lookup returning nil should resolve well under 2s.
        let mock = MockArtworkMatchingLookup()

        let service = FastArtworkLookupService(lookup: mock)
        let start = Date()
        let result = await service.findArtwork(exactTitle: "Slow Game", md5: "00000000", systemID: nil)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertNil(result)
        XCTAssertLessThan(elapsed, 2.0, "Fast lookup returning nil should not block for 2s")
    }

    func testFindArtwork_returnsNilAndCancelsWhenLookupExceedsTimeout() async {
        let lookupStarted = expectation(description: "lookup started")
        let timeoutScheduled = expectation(description: "timeout scheduled")
        let completed = expectation(description: "timeout returned without a lookup result")
        let mock = MockArtworkMatchingLookupSuspended(started: lookupStarted)
        let timeout = ManualArtworkTimeout(scheduled: timeoutScheduled)
        let timeoutNs: UInt64 = 100_000_000
        let service = FastArtworkLookupService(lookup: mock, timeoutNanoseconds: timeoutNs,
                                              timeoutSleep: { try await timeout.sleep(nanoseconds: $0) })
        let operation = Task {
            let result = await service.findArtwork(exactTitle: "Slow Game", md5: "", systemID: nil)
            completed.fulfill()
            return result
        }

        // The timeout wins while the provider is still suspended. The generous expectation
        // deadline is a deadlock watchdog, not an artwork performance benchmark.
        await fulfillment(of: [lookupStarted, timeoutScheduled], timeout: 10)
        let requestedTimeout = await timeout.requestedNanoseconds
        XCTAssertEqual(requestedTimeout, timeoutNs)
        await timeout.fire()
        await fulfillment(of: [completed], timeout: 10)
        let cancelled = await mock.cancellationObserved
        let searches = await mock.searchCount
        // Release a broken implementation as well, so a regression fails rather than hanging.
        await mock.finish()
        operation.cancel()
        let result = await operation.value

        XCTAssertNil(result, "A timed-out lookup must not provide artwork")
        XCTAssertTrue(cancelled, "The timeout must cancel the outstanding provider search")
        XCTAssertEqual(searches, 1)
    }

    func testFindArtwork_cancelsTimeoutWhenLookupWins() async {
        let lookupStarted = expectation(description: "lookup started")
        let timeoutScheduled = expectation(description: "timeout scheduled")
        let completed = expectation(description: "lookup returned before timer fired")
        let mock = MockArtworkMatchingLookupSuspended(started: lookupStarted)
        let timeout = ManualArtworkTimeout(scheduled: timeoutScheduled)
        let expected = "https://example.com/cover.jpg"
        let service = FastArtworkLookupService(lookup: mock,
                                              timeoutSleep: { try await timeout.sleep(nanoseconds: $0) })
        let operation = Task {
            let result = await service.findArtwork(exactTitle: "Some Game", md5: "", systemID: nil)
            completed.fulfill()
            return result
        }
        await fulfillment(of: [lookupStarted, timeoutScheduled], timeout: 10)
        await mock.finish(with: [makeArtwork(urlString: expected)])
        await fulfillment(of: [completed], timeout: 10)
        let cancelled = await timeout.cancellationObserved
        await timeout.fire()
        operation.cancel()
        let result = await operation.value

        XCTAssertEqual(result, expected)
        XCTAssertTrue(cancelled, "A successful lookup must cancel the pending timer")
    }
}
