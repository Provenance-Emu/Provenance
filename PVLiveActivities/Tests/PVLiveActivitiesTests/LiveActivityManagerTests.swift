//
//  LiveActivityManagerTests.swift
//  PVLiveActivitiesTests
//

import XCTest
@testable import PVLiveActivities

final class LiveActivityManagerTests: XCTestCase {

    // MARK: - GameActivityAttributes.ContentState

    func testContentStateDefaultValues() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let state = GameActivityAttributes.ContentState()
            XCTAssertFalse(state.isPaused)
            XCTAssertEqual(state.elapsedSeconds, 0)
            XCTAssertNil(state.achievementPoints)
            XCTAssertNil(state.achievementTotal)
            XCTAssertNil(state.lastSaveDate)
            XCTAssertFalse(state.hasAchievements)
            XCTAssertNil(state.achievementFraction)
        }
        #endif
    }

    func testContentStateElapsedTimeString() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            var state = GameActivityAttributes.ContentState()

            state.elapsedSeconds = 45 * 60
            XCTAssertEqual(state.elapsedTimeString, "45m")

            state.elapsedSeconds = 3600 + 23 * 60
            XCTAssertEqual(state.elapsedTimeString, "1h 23m")

            state.elapsedSeconds = 0
            XCTAssertEqual(state.elapsedTimeString, "0m")
        }
        #endif
    }

    func testAchievementFraction() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            var state = GameActivityAttributes.ContentState()

            // No data → nil
            XCTAssertNil(state.achievementFraction)

            // Zero total → nil (avoid division by zero)
            state.achievementPoints = 10
            state.achievementTotal = 0
            XCTAssertNil(state.achievementFraction)

            // Normal case
            state.achievementPoints = 100
            state.achievementTotal = 400
            XCTAssertEqual(state.achievementFraction, 0.25, accuracy: 0.001)

            // Complete
            state.achievementPoints = 500
            state.achievementTotal = 500
            XCTAssertEqual(state.achievementFraction, 1.0, accuracy: 0.001)
        }
        #endif
    }

    func testAttributesStoredValues() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let attrs = GameActivityAttributes(
                gameTitle: "Super Mario World",
                systemName: "SNES",
                gameMD5: "abc123",
                artworkPath: "Artwork/abc123.png"
            )
            XCTAssertEqual(attrs.gameTitle, "Super Mario World")
            XCTAssertEqual(attrs.systemName, "SNES")
            XCTAssertEqual(attrs.gameMD5, "abc123")
            XCTAssertEqual(attrs.artworkPath, "Artwork/abc123.png")
        }
        #endif
    }
}
