//
//  ArtworkSearchQueueLifecycleTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVLibrary

final class ArtworkSearchQueueLifecycleTests: XCTestCase {

    func test_setPaused_skipsProcessPendingSearches() async {
        let mock = MockArtworkMatchingService()
        await mock.configure(stubbedResults: [])

        let queue = ArtworkSearchQueue(matchingService: mock)
        await queue.setPaused(true)

        await queue.queueGameForArtworkSearch(
            gameID: "paused-test",
            title: "Paused Game",
            filename: "PausedGame",
            systemID: .SNES,
            md5Hash: "abcdef1234567890"
        )
        await queue.processPendingSearches()

        let calls = await mock.calls
        XCTAssertTrue(calls.isEmpty, "Expected no artwork lookups while paused")
        XCTAssertTrue(await queue.isPausedForWork)
    }

    func test_setPaused_resumesProcessing() async {
        let mock = MockArtworkMatchingService()
        await mock.configure(stubbedResults: [])

        let queue = ArtworkSearchQueue(matchingService: mock)
        await queue.setPaused(true)
        await queue.setPaused(false)

        await queue.queueGameForArtworkSearch(
            gameID: "resume-test",
            title: "Resume Game",
            filename: "ResumeGame",
            systemID: .SNES,
            md5Hash: "abcdef1234567891"
        )
        await queue.processPendingSearches()

        let calls = await mock.calls
        XCTAssertFalse(calls.isEmpty, "Expected artwork lookup after resume")
        XCTAssertFalse(await queue.isPausedForWork)
    }
}
