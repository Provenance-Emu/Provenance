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

    func testDefaultIntervalIsAMinute() {
        XCTAssertEqual(RescanThrottle.defaultInterval, 60)
    }
}
