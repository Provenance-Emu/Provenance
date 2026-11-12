import CoreGraphics
import XCTest
@testable import PVCoreBridge

final class WiiTiltFilterTests: XCTestCase {
    func testFaceUpAndOffAreNeutral() {
        var filter = WiiTiltFilter()
        XCTAssertEqual(filter.update(gravity: SIMD3(0, 0, -1), mode: .upright), .zero)
        XCTAssertEqual(filter.update(gravity: SIMD3(1, 0, 0), mode: .off), .zero)
    }

    func testSidewaysRotatesTheAxes() {
        var filter = WiiTiltFilter()
        let gravity = SIMD3<Double>(1, 0, 0)
        for _ in 0..<30 { _ = filter.update(gravity: gravity, mode: .upright) }
        let upright = filter.update(gravity: gravity, mode: .upright)
        let sideways = filter.update(gravity: gravity, mode: .sideways)
        XCTAssertEqual(upright.x, 1)
        XCTAssertEqual(upright.y, 0)
        XCTAssertEqual(sideways.x, 0)
        XCTAssertEqual(sideways.y, -1)
    }

    func testStrongAccelerationDoesNotChangeTilt() {
        var filter = WiiTiltFilter()
        let settled = filter.update(gravity: SIMD3(1, 0, 0), mode: .upright)
        XCTAssertEqual(filter.update(gravity: SIMD3(0, 3, 0), mode: .upright), settled)
    }
}
