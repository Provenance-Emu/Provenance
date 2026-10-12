//
//  RescanThrottleTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class RescanThrottleTests: XCTestCase {
    func testFiresOnceThenWaitsForTheInterval() {
        var throttle = RescanThrottle(interval: 60)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertTrue(throttle.shouldFire(now: start))
        XCTAssertFalse(throttle.shouldFire(now: start.addingTimeInterval(59)))
        XCTAssertTrue(throttle.shouldFire(now: start.addingTimeInterval(60)))
        XCTAssertFalse(throttle.shouldFire(now: start.addingTimeInterval(61)))
    }

    func testRemainingIntervalCountsDownToTheNextAllowedFire() {
        var throttle = RescanThrottle(interval: 60)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertEqual(throttle.remainingInterval(now: start), 0, "nothing has fired yet")
        XCTAssertTrue(throttle.shouldFire(now: start))
        XCTAssertEqual(throttle.remainingInterval(now: start), 60, accuracy: 0.001)
        XCTAssertEqual(throttle.remainingInterval(now: start.addingTimeInterval(45)), 15, accuracy: 0.001)
        XCTAssertEqual(throttle.remainingInterval(now: start.addingTimeInterval(60)), 0, accuracy: 0.001)
        XCTAssertEqual(throttle.remainingInterval(now: start.addingTimeInterval(500)), 0, "never negative")
    }

    func testAThrottledCallDoesNotMoveTheWindow() {
        var throttle = RescanThrottle(interval: 60)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertTrue(throttle.shouldFire(now: start))
        XCTAssertFalse(throttle.shouldFire(now: start.addingTimeInterval(30)))
        XCTAssertEqual(throttle.remainingInterval(now: start.addingTimeInterval(30)), 30, accuracy: 0.001)
    }

    func testDefaultIntervalIsAMinute() {
        XCTAssertEqual(RescanThrottle.defaultInterval, 60)
    }
}
