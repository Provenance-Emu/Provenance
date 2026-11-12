//
//  HeldActionCombinerTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class HeldActionCombinerTests: XCTestCase {

    private enum Source { case touchpad, triggers }

    func testSingleSourcePassesThrough() {
        var combiner = HeldActionCombiner<Source>()
        XCTAssertEqual(combiner.set(.trigger, isDown: true, from: .touchpad), true)
        XCTAssertEqual(combiner.set(.trigger, isDown: false, from: .touchpad), false)
    }

    func testSecondSourceKeepsActionHeld() {
        var combiner = HeldActionCombiner<Source>()
        XCTAssertEqual(combiner.set(.trigger, isDown: true, from: .touchpad), true)
        XCTAssertNil(combiner.set(.trigger, isDown: true, from: .triggers))
        XCTAssertNil(combiner.set(.trigger, isDown: false, from: .touchpad), "R2 still holds it")
        XCTAssertEqual(combiner.set(.trigger, isDown: false, from: .triggers), false)
    }

    func testRepeatedPressFromOneSourceIsIgnored() {
        var combiner = HeldActionCombiner<Source>()
        XCTAssertEqual(combiner.set(.reload, isDown: true, from: .triggers), true)
        XCTAssertNil(combiner.set(.reload, isDown: true, from: .triggers))
        XCTAssertNil(combiner.set(.reload, isDown: false, from: .touchpad), "never pressed by the touchpad")
        XCTAssertEqual(combiner.set(.reload, isDown: false, from: .triggers), false)
    }

    func testReleaseAllFromOneSource() {
        var combiner = HeldActionCombiner<Source>()
        _ = combiner.set(.trigger, isDown: true, from: .triggers)
        _ = combiner.set(.reload, isDown: true, from: .triggers)
        _ = combiner.set(.reload, isDown: true, from: .touchpad)
        XCTAssertEqual(combiner.releaseAll(from: .triggers), [.trigger], "reload stays held by the touchpad")
        XCTAssertEqual(combiner.releaseAll(from: .triggers), [])
        XCTAssertEqual(combiner.set(.reload, isDown: false, from: .touchpad), false)
    }
}
