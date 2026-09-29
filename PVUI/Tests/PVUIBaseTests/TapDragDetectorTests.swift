//
//  TapDragDetectorTests.swift
//  PVUIBaseTests
//
//  The trackpad's tap-then-drag rule: only a touch that lands soon after a tap
//  grabs, and each tap arms a single grab.
//

import Testing
import Foundation
@testable import PVUIBase

struct TapDragDetectorTests {

    @Test func touchWithoutPriorTapDoesNotGrab() {
        var detector = TapDragDetector()
        let grabbed = detector.touchBegan(at: 10)
        #expect(!grabbed)
    }

    @Test func touchInsideWindowAfterTapGrabs() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        let grabbed = detector.touchBegan(at: 10.2)
        #expect(grabbed)
    }

    @Test func touchAtWindowEdgeGrabs() {
        // Binary-exact values, so the boundary isn't lost to rounding.
        var detector = TapDragDetector(window: 0.25)
        detector.tapEnded(at: 10)
        let grabbed = detector.touchBegan(at: 10.25)
        #expect(grabbed)
    }

    @Test func touchAfterWindowDoesNotGrab() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        let grabbed = detector.touchBegan(at: 10.5)
        #expect(!grabbed)
    }

    @Test func tapArmsOnlyOneGrab() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        let first = detector.touchBegan(at: 10.1)
        #expect(first)
        let second = detector.touchBegan(at: 10.2)
        #expect(!second)
    }

    @Test func lateTouchDisarms() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        let late = detector.touchBegan(at: 11)
        #expect(!late)
        let next = detector.touchBegan(at: 11.1)
        #expect(!next)
    }
}
