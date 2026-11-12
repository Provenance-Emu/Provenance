//
//  TouchpadGestureRecognizerTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class TouchpadGestureRecognizerTests: XCTestCase {

    private var recognizer = TouchpadGestureRecognizer()
    private var clock: TimeInterval = 0

    override func setUp() {
        super.setUp()
        recognizer = TouchpadGestureRecognizer()
        clock = 0
    }

    /// Feeds one sample, 1/60 s after the previous one unless `after` says otherwise.
    @discardableResult
    private func feed(
        _ first: (Float, Float)? = nil, _ second: (Float, Float)? = nil, click: Bool = false, after: TimeInterval = 1.0 / 60
    ) -> [TouchpadEvent] {
        clock += after
        let sample = TouchpadSample(
            primary: first.map { TouchpadPoint(x: $0.0, y: $0.1) },
            secondary: second.map { TouchpadPoint(x: $0.0, y: $0.1) },
            isClicked: click)
        return recognizer.update(sample, at: clock)
    }

    private func movement(in events: [TouchpadEvent]) -> (dx: Float, dy: Float)? {
        for case let .moved(dx, dy) in events { return (dx, dy) }
        return nil
    }

    // MARK: - Samples

    func testRawZeroIsFingerUp() {
        let lifted = TouchpadSample(primaryX: 0, primaryY: 0, secondaryX: 0, secondaryY: 0, isClicked: false)
        XCTAssertNil(lifted.primary)
        XCTAssertNil(lifted.secondary)
        XCTAssertEqual(lifted.fingerCount, 0)

        let touching = TouchpadSample(primaryX: 0, primaryY: 0.01, secondaryX: 0, secondaryY: 0, isClicked: true)
        XCTAssertEqual(touching.primary, TouchpadPoint(x: 0, y: 0.01))
        XCTAssertEqual(touching.fingerCount, 1)
        XCTAssertTrue(touching.isClicked)
    }

    // MARK: - One finger

    func testFirstSampleAfterLandingHasNoDelta() {
        XCTAssertEqual(feed((0.8, -0.6)), [.touchBegan])
    }

    func testDragEmitsDeltaWithScreenY() throws {
        feed((0.0, 0.2))
        let moved = try XCTUnwrap(movement(in: feed((0.25, 0.5))))
        XCTAssertEqual(moved.dx, 0.25, accuracy: 0.0001)
        /// The finger went up the pad, which is up the screen: negative.
        XCTAssertEqual(moved.dy, -0.3, accuracy: 0.0001)
    }

    func testLiftEmitsNoDelta() {
        feed((0.5, 0.5))
        feed((0.6, 0.5))
        XCTAssertEqual(feed(nil), [.touchEnded])
    }

    func testCentreCrossingProducesNoJump() {
        feed((-0.1, 0.2))
        /// The exact centre reads as a lifted finger.
        let atCentre = recognizer.update(
            TouchpadSample(primaryX: 0, primaryY: 0, secondaryX: 0, secondaryY: 0, isClicked: false), at: clock + 0.016)
        XCTAssertNil(movement(in: atCentre))
        XCTAssertNil(movement(in: feed((0.1, 0.2), after: 0.032)))
        /// Movement resumes from the new position.
        XCTAssertNotNil(movement(in: feed((0.2, 0.2))))
    }

    func testStationaryFingerEmitsNothing() {
        feed((0.3, 0.3))
        XCTAssertEqual(feed((0.3, 0.3)), [])
    }

    // MARK: - Clicks

    func testClickZones() {
        XCTAssertEqual(feed((-0.4, 0.1), click: true), [.touchBegan, .clickDown(.left)])
        XCTAssertEqual(feed((-0.4, 0.1)), [.clickUp(.left)])
        feed(nil)

        XCTAssertEqual(feed((0.4, 0.1), click: true), [.touchBegan, .clickDown(.right)])
        XCTAssertEqual(feed((0.4, 0.1)), [.clickUp(.right)])
    }

    func testClickWithNoFingerIsLeft() {
        XCTAssertEqual(feed(nil, click: true), [.clickDown(.left)])
        XCTAssertEqual(feed(nil), [.clickUp(.left)])
    }

    func testClickUpKeepsDownZone() {
        feed((-0.5, 0))
        XCTAssertEqual(feed((-0.5, 0), click: true), [.clickDown(.left)])
        /// The finger slides to the right half while the pad is held down.
        feed((0.5, 0), click: true)
        XCTAssertTrue(feed((0.5, 0)).contains(.clickUp(.left)))
    }

    func testHeldClickFiresOnce() {
        XCTAssertEqual(feed((0.2, 0.2), click: true), [.touchBegan, .clickDown(.right)])
        XCTAssertEqual(feed((0.2, 0.2), click: true), [])
    }

    // MARK: - Two fingers

    func testTwoFingersFreezeMovement() {
        feed((-0.5, 0))
        feed((-0.4, 0))
        XCTAssertNil(movement(in: feed((-0.3, 0), (0.5, 0))))
        XCTAssertNil(movement(in: feed((-0.2, 0.05), (0.6, 0.05))))
        /// Back to one finger: the first sample re-bases, the next one moves.
        XCTAssertNil(movement(in: feed((-0.2, 0.05), after: 0.5)))
        XCTAssertNotNil(movement(in: feed((-0.1, 0.05))))
    }

    func testTwoFingerTap() {
        XCTAssertEqual(feed((-0.3, 0.1), (0.3, 0.1)), [.touchBegan])
        XCTAssertEqual(feed((-0.3, 0.1), (0.3, 0.1), after: 0.05), [])
        XCTAssertEqual(feed(nil, after: 0.05), [.twoFingerTap, .touchEnded])
    }

    func testSlowTwoFingerLiftIsNotATap() {
        feed((-0.3, 0.1), (0.3, 0.1))
        XCTAssertEqual(feed(nil, after: 0.6), [.touchEnded])
    }

    func testTwoFingerTapThatTravelsIsNotATap() {
        feed((-0.3, 0.0), (0.3, 0.0))
        feed((-0.3, 0.2), (0.3, 0.2), after: 0.05)
        XCTAssertFalse(feed(nil, after: 0.05).contains(.twoFingerTap))
    }

    func testTwoFingerSlideSteps() {
        feed((-0.3, -0.3), (0.3, -0.3))
        /// 0.65 of upward travel at 0.3 per step: two steps, with the rest carried.
        XCTAssertEqual(feed((-0.3, 0.35), (0.3, 0.35), after: 0.3), [.twoFingerSlide(steps: 2)])
        XCTAssertEqual(feed((-0.3, 0.4), (0.3, 0.4)), [])
        /// Back down past the anchor.
        XCTAssertEqual(feed((-0.3, -0.05), (0.3, -0.05)), [.twoFingerSlide(steps: -1)])
        /// A slide does not end as a tap.
        XCTAssertEqual(feed(nil), [.touchEnded])
    }

    func testTwoFingerClickCancelsSlideAndTap() {
        feed((-0.3, 0.0), (0.3, 0.0))
        XCTAssertEqual(feed((-0.3, 0.0), (0.3, 0.0), click: true), [.clickDown(.twoFinger)])
        /// The fingers keep sliding with the pad held down: no speed change.
        XCTAssertEqual(feed((-0.3, 0.7), (0.3, 0.7), click: true), [])
        XCTAssertEqual(feed((-0.3, 0.7), (0.3, 0.7)), [.clickUp(.twoFinger)])
        /// And lifting quickly afterwards is not a tap.
        XCTAssertEqual(feed(nil), [.touchEnded])
    }

    // MARK: - Reset

    func testResetEmitsNothing() {
        feed((0.5, 0.5), click: true)
        recognizer.reset()
        /// The held click and the finger are forgotten: the same sample reads as fresh input.
        XCTAssertEqual(feed((0.5, 0.5), click: true), [.touchBegan, .clickDown(.right)])
    }
}
