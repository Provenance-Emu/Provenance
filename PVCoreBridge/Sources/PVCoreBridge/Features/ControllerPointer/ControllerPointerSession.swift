//
//  ControllerPointerSession.swift
//  PVCoreBridge
//
//  Touchpad samples in, cursor movement and button actions out.
//

import CoreGraphics
import Foundation

/// What the pointer did, ready to hand to a core.
public enum PointerOutput: Equatable, Sendable {
    /// A finger is on the pad, or the last one left.
    case touching(Bool)
    /// The cursor moved. Both values are fractions of the emulated screen.
    case moved(delta: CGPoint, position: CGPoint)
    /// A bound action was pressed or released. `pauseMenu` only ever arrives pressed.
    case action(PointerAction, isDown: Bool)
    /// The player recentred the cursor.
    case recentered(position: CGPoint)
    /// The player changed the pointer speed from the pad.
    case speedChanged(Double)
}

/// One game's pointer: holds the cursor and turns touchpad samples into `PointerOutput`s.
public struct ControllerPointerSession: Sendable {
    /// How much one two-finger slide step changes the speed.
    public static let speedStep = 0.2

    public var curve: PointerSpeedCurve
    public var bindings: PointerClickBindings
    public private(set) var cursor = PointerCursor()

    private var recognizer: TouchpadGestureRecognizer
    private var heldActions: [TouchpadClickZone: PointerAction] = [:]
    private var isTouching = false
    private var lastTime: TimeInterval?
    /// After a reset a press that is still held is ignored until the pad is let go, so the
    /// press that opened the pause menu (or one held through it) is not delivered again.
    private var isAwaitingClickRelease = false

    public init(curve: PointerSpeedCurve = PointerSpeedCurve(), bindings: PointerClickBindings,
                tuning: TouchpadGestureRecognizer.Tuning = TouchpadGestureRecognizer.Tuning()) {
        self.curve = curve
        self.bindings = bindings
        self.recognizer = TouchpadGestureRecognizer(tuning: tuning)
    }

    /// Another input source (a mouse, the touch screen) moved the cursor; continue from there.
    public mutating func adoptCursor(_ position: CGPoint) {
        cursor.set(position)
    }

    /// Moves the cursor by a delta from another pointer input on the same pad (its gyro),
    /// so the touchpad and the gyro move one cursor. Returns nil when nothing moved.
    public mutating func nudge(dx: Double, dy: Double) -> PointerOutput? {
        let applied = cursor.apply(dx: dx, dy: dy)
        guard applied != .zero else { return nil }
        return .moved(delta: applied, position: cursor.position)
    }

    /// Releases everything that is held and forgets the touch in progress.
    ///
    /// Call when the pad goes away, the role changes, the game pauses or the session ends,
    /// and deliver what it returns so no button stays down in the core.
    public mutating func reset() -> [PointerOutput] {
        var outputs = TouchpadClickZone.allCases.compactMap { zone in
            heldActions[zone].map { PointerOutput.action($0, isDown: false) }
        }
        if isTouching { outputs.append(.touching(false)) }
        heldActions.removeAll()
        isTouching = false
        lastTime = nil
        recognizer.reset()
        isAwaitingClickRelease = true
        return outputs
    }

    public mutating func update(_ sample: TouchpadSample, at time: TimeInterval) -> [PointerOutput] {
        let dt = lastTime.map { time - $0 } ?? 0
        lastTime = time

        let ignoresClicks = isAwaitingClickRelease
        if !sample.isClicked { isAwaitingClickRelease = false }

        var outputs: [PointerOutput] = []
        for event in recognizer.update(sample, at: time) {
            switch event {
            case .touchBegan:
                isTouching = true
                outputs.append(.touching(true))
            case .touchEnded:
                isTouching = false
                outputs.append(.touching(false))
            case let .moved(dx, dy):
                let delta = curve.screenDelta(padDX: Double(dx), padDY: Double(dy), dt: dt)
                let applied = cursor.apply(dx: delta.dx, dy: delta.dy)
                if applied != .zero { outputs.append(.moved(delta: applied, position: cursor.position)) }
            case let .clickDown(zone):
                guard !ignoresClicks else { continue }
                press(bindings[zone], zone: zone, into: &outputs)
            case let .clickUp(zone):
                if let action = heldActions.removeValue(forKey: zone) {
                    outputs.append(.action(action, isDown: false))
                }
            case .twoFingerTap:
                cursor.recenter()
                outputs.append(.recentered(position: cursor.position))
            case let .twoFingerSlide(steps):
                changeSpeed(bySteps: steps, into: &outputs)
            }
        }
        return outputs
    }

    private mutating func press(_ action: PointerAction, zone: TouchpadClickZone, into outputs: inout [PointerOutput]) {
        switch action {
        case .none:
            break
        case .pauseMenu:
            outputs.append(.action(.pauseMenu, isDown: true))
        default:
            heldActions[zone] = action
            outputs.append(.action(action, isDown: true))
        }
    }

    private mutating func changeSpeed(bySteps steps: Int, into outputs: inout [PointerOutput]) {
        let range = PointerSpeedCurve.speedRange
        let raw = curve.speed + Double(steps) * Self.speedStep
        /// Rounded to the step's precision so repeated steps do not drift.
        let stepped = (min(max(raw, range.lowerBound), range.upperBound) * 10).rounded() / 10
        guard stepped != curve.speed else { return }
        curve.speed = stepped
        outputs.append(.speedChanged(stepped))
    }
}
