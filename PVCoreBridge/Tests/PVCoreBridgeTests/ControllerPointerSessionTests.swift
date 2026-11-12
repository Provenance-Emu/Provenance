//
//  ControllerPointerSessionTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class ControllerPointerSessionTests: XCTestCase {

    private static let frame: TimeInterval = 1.0 / 60

    private var session = ControllerPointerSession(bindings: .defaults(for: .mouse))
    private var clock: TimeInterval = 0

    override func setUp() {
        super.setUp()
        /// No acceleration, so distances are exact.
        session = ControllerPointerSession(
            curve: PointerSpeedCurve(speed: 1, acceleration: 0), bindings: .defaults(for: .mouse))
        clock = 0
    }

    @discardableResult
    private func feed(
        _ first: (Float, Float)? = nil, _ second: (Float, Float)? = nil, click: Bool = false,
        after: TimeInterval = ControllerPointerSessionTests.frame
    ) -> [PointerOutput] {
        clock += after
        let sample = TouchpadSample(
            primary: first.map { TouchpadPoint(x: $0.0, y: $0.1) },
            secondary: second.map { TouchpadPoint(x: $0.0, y: $0.1) },
            isClicked: click)
        return session.update(sample, at: clock)
    }

    private func actions(in outputs: [PointerOutput]) -> [PointerOutput] {
        outputs.filter { if case .action = $0 { return true } else { return false } }
    }

    private func hasMovement(_ outputs: [PointerOutput]) -> Bool {
        outputs.contains { if case .moved = $0 { return true } else { return false } }
    }

    // MARK: - Speed curve

    func testZeroInZeroOut() {
        let curve = PointerSpeedCurve(speed: 3, acceleration: 1)
        let delta = curve.screenDelta(padDX: 0, padDY: 0, dt: Self.frame)
        XCTAssertEqual(delta.dx, 0)
        XCTAssertEqual(delta.dy, 0)
    }

    func testFullSweepAtSpeedOneCrossesScreen() {
        let curve = PointerSpeedCurve(speed: 1, acceleration: 0)
        let delta = curve.screenDelta(padDX: 2, padDY: -2, dt: 1)
        XCTAssertEqual(delta.dx, 1, accuracy: 0.0001)
        XCTAssertEqual(delta.dy, -1, accuracy: 0.0001)
    }

    func testSpeedScalesLinearly() {
        let slow = PointerSpeedCurve(speed: 1, acceleration: 0).screenDelta(padDX: 0.2, padDY: 0, dt: Self.frame)
        let fast = PointerSpeedCurve(speed: 2.5, acceleration: 0).screenDelta(padDX: 0.2, padDY: 0, dt: Self.frame)
        XCTAssertEqual(fast.dx, slow.dx * 2.5, accuracy: 0.0001)
    }

    func testFasterNeverTravelsLess() {
        let curve = PointerSpeedCurve(speed: 1, acceleration: 1)
        var previous = 0.0
        /// The same distance covered in less and less time.
        for dt in [1.0, 0.5, 0.1, 0.05, 0.016, 0.004] {
            let travelled = curve.screenDelta(padDX: 0.5, padDY: 0, dt: dt).dx
            XCTAssertGreaterThanOrEqual(travelled, previous)
            previous = travelled
        }
        XCTAssertGreaterThan(previous, curve.screenDelta(padDX: 0.5, padDY: 0, dt: 1).dx)
    }

    func testCurveClampsItsSettings() {
        let curve = PointerSpeedCurve(speed: 99, acceleration: -4)
        XCTAssertEqual(curve.speed, PointerSpeedCurve.speedRange.upperBound)
        XCTAssertEqual(curve.acceleration, 0)
    }

    // MARK: - Cursor

    func testClampsAndReportsAppliedDelta() {
        var cursor = PointerCursor(position: CGPoint(x: 0.9, y: 0.5))
        let applied = cursor.apply(dx: 0.3, dy: -0.1)
        XCTAssertEqual(cursor.position.x, 1)
        XCTAssertEqual(applied.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(applied.y, -0.1, accuracy: 0.0001)
        XCTAssertEqual(cursor.apply(dx: 0.2, dy: 0), .zero)
    }

    func testRecenter() {
        var cursor = PointerCursor(position: CGPoint(x: 0.1, y: 0.9))
        cursor.recenter()
        XCTAssertEqual(cursor.position, PointerCursor.centre)
        cursor.set(CGPoint(x: -3, y: 7))
        XCTAssertEqual(cursor.position, CGPoint(x: 0, y: 1))
    }

    // MARK: - Session

    func testDragMovesCursor() throws {
        XCTAssertEqual(feed((0.0, 0.5)), [.touching(true)])
        let outputs = feed((0.2, 0.3))
        guard case let .moved(delta, position)? = outputs.first else { return XCTFail("no movement: \(outputs)") }
        /// 0.2 pad units right and 0.2 down the screen, at half a screen per pad unit.
        XCTAssertEqual(delta.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(delta.y, 0.1, accuracy: 0.0001)
        XCTAssertEqual(position.x, 0.6, accuracy: 0.0001)
        XCTAssertEqual(position.y, 0.6, accuracy: 0.0001)
        XCTAssertEqual(session.cursor.position, position)
    }

    func testMovementAgainstAnEdgeIsNotReported() {
        session.adoptCursor(CGPoint(x: 1, y: 0.5))
        feed((0.0, 0.5))
        XCTAssertFalse(hasMovement(feed((0.4, 0.5))))
    }

    func testClickMapsThroughBindings() {
        XCTAssertEqual(actions(in: feed((-0.5, 0.1), click: true)), [.action(.leftButton, isDown: true)])
        XCTAssertEqual(actions(in: feed((-0.5, 0.1))), [.action(.leftButton, isDown: false)])
        feed(nil)

        XCTAssertEqual(actions(in: feed((-0.3, 0.1), (0.3, 0.1), click: true)), [.action(.rightButton, isDown: true)])
        XCTAssertEqual(actions(in: feed((-0.3, 0.1), (0.3, 0.1))), [.action(.rightButton, isDown: false)])
    }

    func testUnboundZoneDoesNothing() {
        session.bindings = PointerClickBindings(left: .none, right: .leftButton, twoFinger: .none)
        XCTAssertEqual(actions(in: feed((-0.5, 0.1), click: true)), [])
        XCTAssertEqual(actions(in: feed((-0.5, 0.1))), [])
    }

    func testPauseActionOnlyOnDown() {
        session.bindings = .defaults(for: .lightGun)
        XCTAssertEqual(actions(in: feed((-0.3, 0.1), (0.3, 0.1), click: true)), [.action(.pauseMenu, isDown: true)])
        XCTAssertEqual(actions(in: feed((-0.3, 0.1), (0.3, 0.1))), [])
    }

    func testTwoFingerTapRecenters() {
        session.adoptCursor(CGPoint(x: 0.1, y: 0.2))
        feed((-0.3, 0.1), (0.3, 0.1))
        let outputs = feed(nil, after: 0.05)
        XCTAssertTrue(outputs.contains(.recentered(position: PointerCursor.centre)))
        XCTAssertEqual(session.cursor.position, PointerCursor.centre)
    }

    func testSlideChangesSpeedAndClamps() {
        feed((-0.3, -0.3), (0.3, -0.3))
        XCTAssertEqual(feed((-0.3, 0.35), (0.3, 0.35), after: 0.3), [.speedChanged(1.4)])
        XCTAssertEqual(session.curve.speed, 1.4, accuracy: 0.0001)

        session.curve.speed = PointerSpeedCurve.speedRange.upperBound
        /// Already at the top: another step up changes nothing and reports nothing.
        XCTAssertEqual(feed((-0.3, 0.7), (0.3, 0.7), after: 0.3), [])
        XCTAssertEqual(session.curve.speed, PointerSpeedCurve.speedRange.upperBound)
    }

    func testSlideDownStopsAtTheMinimum() {
        session.curve.speed = 0.2
        feed((-0.3, 0.9), (0.3, 0.9))
        XCTAssertEqual(feed((-0.3, -0.9), (0.3, -0.9), after: 0.3), [.speedChanged(0.1)])
    }

    func testAdoptCursorContinuesFromThere() {
        feed((0.0, 0.5))
        session.adoptCursor(CGPoint(x: 0.2, y: 0.2))
        guard case let .moved(_, position)? = feed((0.2, 0.5)).first else { return XCTFail("no movement") }
        XCTAssertEqual(position.x, 0.3, accuracy: 0.0001)
        XCTAssertEqual(position.y, 0.2, accuracy: 0.0001)
    }

    // MARK: - Reset (pad lost, role changed, game paused)

    func testResetReleasesHeldActions() {
        feed((-0.5, 0.1), click: true)
        XCTAssertEqual(session.reset(), [.action(.leftButton, isDown: false), .touching(false)])
        /// Nothing is left to release.
        XCTAssertEqual(session.reset(), [])
    }

    func testHeldClickAcrossResetDoesNotRefire() {
        feed((-0.5, 0.1), click: true)
        _ = session.reset()
        /// The pad is still held down when sampling resumes.
        XCTAssertEqual(actions(in: feed((-0.5, 0.1), click: true)), [])
        XCTAssertEqual(actions(in: feed((-0.5, 0.1))), [])
        /// A fresh press works again.
        XCTAssertEqual(actions(in: feed((-0.5, 0.1), click: true)), [.action(.leftButton, isDown: true)])
    }

    func testNoStaleDeltaAfterReset() {
        feed((-0.8, 0.0))
        feed((-0.7, 0.0))
        _ = session.reset()
        /// The finger is somewhere else entirely when sampling resumes.
        XCTAssertFalse(hasMovement(feed((0.8, 0.6), after: 3)))
        XCTAssertTrue(hasMovement(feed((0.7, 0.6))))
    }
}
