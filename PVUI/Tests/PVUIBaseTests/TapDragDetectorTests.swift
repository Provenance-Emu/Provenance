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
        #expect(!detector.touchBegan(at: 10))
    }

    @Test func touchInsideWindowAfterTapGrabs() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        #expect(detector.touchBegan(at: 10.2))
    }

    @Test func touchAtWindowEdgeGrabs() {
        // Binary-exact values, so the boundary isn't lost to rounding.
        var detector = TapDragDetector(window: 0.25)
        detector.tapEnded(at: 10)
        #expect(detector.touchBegan(at: 10.25))
    }

    @Test func touchAfterWindowDoesNotGrab() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        #expect(!detector.touchBegan(at: 10.5))
    }

    @Test func tapArmsOnlyOneGrab() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        #expect(detector.touchBegan(at: 10.1))
        #expect(!detector.touchBegan(at: 10.2))
    }

    @Test func lateTouchDisarms() {
        var detector = TapDragDetector(window: 0.3)
        detector.tapEnded(at: 10)
        #expect(!detector.touchBegan(at: 11))
        #expect(!detector.touchBegan(at: 11.1))
    }
}
