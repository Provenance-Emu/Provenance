//
//  TouchTrackpadMovementTests.swift
//  PVUIBaseTests
//
//  A machine that draws its own pointer is sent movement, never positions: a position
//  stops at the edge of its range while the real pointer may still be mid-screen.
//

#if os(iOS)
import Testing
import UIKit
import GameController
import PVCoreBridge
import SkinKitCore
@testable import PVUIBase

private final class RecordingMouse: NSObject, MouseResponder {
    var gameSupportsMouse: Bool { true }
    var requiresMouse: Bool { false }
    func didScroll(_ cursor: GCDeviceCursor) {}
    var mouseMovedHandler: GCMouseMoved? { nil }

    var positions: [CGPoint] = []
    var deltas: [CGPoint] = []

    func mouseMoved(atPoint point: CGPoint) { positions.append(point) }
    func mouseMoved(byNormalizedDelta delta: CGPoint) { deltas.append(delta) }
    func leftMouseDown(atPoint point: CGPoint) {}
    func leftMouseUp() {}
    func rightMouseDown(atPoint point: CGPoint) {}
    func rightMouseUp() {}
}

/// A core from before `mouseMoved(byNormalizedDelta:)`.
private final class PositionOnlyMouse: NSObject, MouseResponder {
    var gameSupportsMouse: Bool { true }
    var requiresMouse: Bool { false }
    func didScroll(_ cursor: GCDeviceCursor) {}
    var mouseMovedHandler: GCMouseMoved? { nil }

    var positions: [CGPoint] = []

    func mouseMoved(atPoint point: CGPoint) { positions.append(point) }
    func leftMouseDown(atPoint point: CGPoint) {}
    func leftMouseUp() {}
    func rightMouseDown(atPoint point: CGPoint) {}
    func rightMouseUp() {}
}

@MainActor
struct TouchTrackpadMovementTests {

    /// Three sweeps to the right are all delivered. As positions the second and third were
    /// lost at the edge, which left the DOS pointer unable to cross the screen.
    @Test func relativeMovementIsNeverClamped() {
        let mouse = RecordingMouse()
        let trackpad = TouchTrackpadView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        trackpad.mouseResponder = mouse
        trackpad.sendsRelativeMovement = true

        for _ in 0..<3 { trackpad.moveCursor(by: CGPoint(x: 0.4, y: 0)) }

        #expect(mouse.deltas == Array(repeating: CGPoint(x: 0.4, y: 0), count: 3))
        #expect(mouse.positions.isEmpty)
    }

    @Test func positionsStopAtTheEdge() {
        let mouse = RecordingMouse()
        let trackpad = TouchTrackpadView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        trackpad.mouseResponder = mouse

        for _ in 0..<3 { trackpad.moveCursor(by: CGPoint(x: 0.4, y: 0)) }

        #expect(mouse.deltas.isEmpty)
        #expect(mouse.positions.map(\.x) == [0.9, 1, 1])
    }

    @Test func coreWithoutRelativeMovementGetsPositions() {
        let mouse = PositionOnlyMouse()
        let trackpad = TouchTrackpadView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        trackpad.mouseResponder = mouse
        trackpad.sendsRelativeMovement = true

        trackpad.moveCursor(by: CGPoint(x: 0.25, y: 0.25))

        #expect(mouse.positions == [CGPoint(x: 0.75, y: 0.75)])
    }

    /// A touch on an on-screen control is left to it.
    @Test func yieldedTouchIsNotTaken() {
        let trackpad = TouchTrackpadView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        trackpad.explicitGameViewRect = trackpad.frame
        trackpad.yieldsTouch = { point, _ in point.x < 100 }

        #expect(trackpad.hitTest(CGPoint(x: 50, y: 50), with: nil) == nil)
        #expect(trackpad.hitTest(CGPoint(x: 200, y: 50), with: nil) === trackpad)
    }
}

struct VirtualKeyboardVariantChoiceTests {

    @Test func untouchedChoiceGivesWayToTheMachinesKeyboard() {
        #expect(VirtualKeyboardVariant.resolved(chosen: .full, systemDefault: .atariST) == .atariST)
        #expect(VirtualKeyboardVariant.resolved(chosen: nil, systemDefault: .c64) == .c64)
    }

    @Test func aPickedLayoutWins() {
        #expect(VirtualKeyboardVariant.resolved(chosen: .compact, systemDefault: .atariST) == .compact)
    }

    @Test func fullIsTheFallback() {
        #expect(VirtualKeyboardVariant.resolved(chosen: nil, systemDefault: nil) == .full)
        #expect(VirtualKeyboardVariant.resolved(chosen: .full, systemDefault: nil) == .full)
    }
}
#endif
