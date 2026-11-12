//
//  GyroPointerFilterTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class GyroPointerFilterTests: XCTestCase {

    private let second: TimeInterval = 1

    func testStillPadDoesNotMove() {
        let filter = GyroPointerFilter(deadZone: 0.05)
        XCTAssertEqual(filter.screenDelta(yawRate: 0.04, pitchRate: -0.04, dt: second), .zero)
    }

    func testTurningRightMovesRight() {
        let filter = GyroPointerFilter(deadZone: 0)
        let delta = filter.screenDelta(yawRate: 1, pitchRate: 0, dt: second)
        XCTAssertEqual(delta.x, GyroPointerFilter.screensPerRadian, accuracy: 1e-9)
        XCTAssertEqual(delta.y, 0)
    }

    func testTiltingUpMovesUp() {
        let filter = GyroPointerFilter(deadZone: 0)
        XCTAssertLessThan(filter.screenDelta(yawRate: 0, pitchRate: 1, dt: second).y, 0)
    }

    func testDeadZoneIsSubtractedNotJumped() {
        let filter = GyroPointerFilter(deadZone: 0.1)
        let delta = filter.screenDelta(yawRate: 0.2, pitchRate: -0.2, dt: second)
        XCTAssertEqual(delta.x, 0.1 * GyroPointerFilter.screensPerRadian, accuracy: 1e-9)
        XCTAssertEqual(delta.y, 0.1 * GyroPointerFilter.screensPerRadian, accuracy: 1e-9)
    }

    func testSensitivityAndInversion() {
        let filter = GyroPointerFilter(sensitivity: 2, deadZone: 0, invertX: true, invertY: true)
        let delta = filter.screenDelta(yawRate: 1, pitchRate: 1, dt: 0.5)
        XCTAssertEqual(delta.x, -GyroPointerFilter.screensPerRadian, accuracy: 1e-9)
        XCTAssertEqual(delta.y, GyroPointerFilter.screensPerRadian, accuracy: 1e-9)
    }

    func testOutOfRangeValuesAreClamped() {
        let filter = GyroPointerFilter(sensitivity: 50, deadZone: -1)
        XCTAssertEqual(filter.sensitivity, GyroPointerFilter.sensitivityRange.upperBound)
        XCTAssertEqual(filter.deadZone, 0)
    }

    func testZeroTimeIsNoMovement() {
        XCTAssertEqual(GyroPointerFilter().screenDelta(yawRate: 3, pitchRate: 3, dt: 0), .zero)
    }
}
