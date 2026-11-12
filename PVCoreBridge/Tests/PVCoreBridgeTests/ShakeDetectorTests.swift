//
//  ShakeDetectorTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class ShakeDetectorTests: XCTestCase {

    private let frame = 1.0 / 60.0
    private let resting = SIMD3<Double>(0, 0, -1)

    /// Feeds `count` samples one frame apart from `start`; returns every state change.
    private func feed(_ detector: inout ShakeDetector, count: Int, from start: TimeInterval = 0,
                      _ sample: (Int) -> SIMD3<Double>) -> [Bool] {
        var changes: [Bool] = []
        for index in 0..<count {
            if let change = detector.update(acceleration: sample(index), at: start + Double(index) * frame) {
                changes.append(change)
            }
        }
        return changes
    }

    func testStillPadNeverShakes() {
        var detector = ShakeDetector()
        XCTAssertEqual(feed(&detector, count: 120) { _ in self.resting }, [])
    }

    func testFirstSampleNeverFires() {
        var detector = ShakeDetector()
        XCTAssertNil(detector.update(acceleration: SIMD3(3, 0, 0), at: 0))
        XCTAssertFalse(detector.isShaking)
    }

    func testJoltStartsShake() {
        var detector = ShakeDetector()
        _ = feed(&detector, count: 30) { _ in self.resting }
        XCTAssertEqual(detector.update(acceleration: SIMD3(2, 0, -1), at: 30 * frame), true)
        XCTAssertTrue(detector.isShaking)
    }

    func testShakeHoldsThroughZeroCrossings() {
        var detector = ShakeDetector()
        _ = feed(&detector, count: 30) { _ in self.resting }
        /// ±2 g swapping every three frames (50 ms), with the turnarounds reading plain gravity.
        let shaking = feed(&detector, count: 60, from: 30 * frame) { index in
            switch index % 6 {
            case 0, 1: return SIMD3(2, 0, -1)
            case 3, 4: return SIMD3(-2, 0, -1)
            default: return self.resting
            }
        }
        XCTAssertEqual(shaking, [true], "one press, held for the whole shake")

        /// Still again: released once the hold runs out, and only once.
        let after = feed(&detector, count: 30, from: 90 * frame) { _ in self.resting }
        XCTAssertEqual(after, [false])
    }

    func testReleaseWaitsForHoldDuration() {
        var detector = ShakeDetector()
        _ = feed(&detector, count: 30) { _ in self.resting }
        _ = detector.update(acceleration: SIMD3(2, 0, -1), at: 30 * frame)
        let joltTime = 30 * frame
        XCTAssertNil(detector.update(acceleration: resting, at: joltTime + 0.1))
        XCTAssertEqual(detector.update(acceleration: resting, at: joltTime + 0.16), false)
    }

    func testSlowTiltDoesNotShake() {
        var detector = ShakeDetector()
        /// Gravity turns from -z to +x over one second.
        let changes = feed(&detector, count: 61) { index in
            let angle = Double(index) / 60 * .pi / 2
            return SIMD3(sin(angle), 0, -cos(angle))
        }
        XCTAssertEqual(changes, [])
    }

    func testResetReleases() {
        var detector = ShakeDetector()
        _ = detector.update(acceleration: resting, at: 0)
        _ = detector.update(acceleration: SIMD3(2, 0, -1), at: frame)
        XCTAssertEqual(detector.reset(), false)
        XCTAssertNil(detector.reset())
        XCTAssertNil(detector.update(acceleration: SIMD3(3, 0, 0), at: 2 * frame), "first sample after reset")
    }

    // MARK: - Shared ports

    func testSharedPortHeldUntilLastPlayerStops() {
        var port = SharedShakeState()
        XCTAssertEqual(port.set(true, player: 0, port: 4), true)
        XCTAssertNil(port.set(true, player: 1, port: 4))
        XCTAssertNil(port.set(false, player: 0, port: 4))
        XCTAssertEqual(port.set(false, player: 1, port: 4), false)
    }

    func testSeparatePortsAreIndependent() {
        var port = SharedShakeState()
        XCTAssertEqual(port.set(true, player: 0, port: 4), true)
        XCTAssertEqual(port.set(true, player: 1, port: 5), true)
        XCTAssertEqual(port.set(false, player: 0, port: 4), false)
        XCTAssertNil(port.set(false, player: 2, port: 5), "a player who never shook changes nothing")
    }
}
