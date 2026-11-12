//
//  TouchpadGestureRecognizer.swift
//  PVCoreBridge
//
//  Turns successive touchpad samples into movement, clicks and two-finger gestures.
//

import Foundation

/// Turns successive `TouchpadSample`s into `TouchpadEvent`s.
///
/// The pad is sampled, never observed through handlers, so this holds the previous
/// sample's state and reports what changed.
///
/// Guarantees:
/// - a finger landing or lifting never produces movement, so a cursor cannot jump;
/// - nothing moves while two fingers are down;
/// - a click with two fingers down is a two-finger click and nothing else: it cancels
///   the tap and the slide that were in progress.
public struct TouchpadGestureRecognizer: Sendable {

    public struct Tuning: Equatable, Sendable {
        /// The longest two fingers may stay down and still count as a tap.
        public var tapMaxDuration: TimeInterval = 0.25
        /// The furthest the two fingers' midpoint may travel and still count as a tap, in pad units.
        public var tapMaxTravel: Float = 0.15
        /// Vertical travel of the two fingers' midpoint for one slide step, in pad units.
        public var slideStepTravel: Float = 0.3

        public init() {}
    }

    /// A two-finger contact from the moment the second finger lands until one lifts.
    private struct TwoFingerContact: Sendable {
        var startTime: TimeInterval
        var startMidpoint: TouchpadPoint
        /// The midpoint height the next slide step is measured from.
        var slideAnchorY: Float
        var maxTravel: Float = 0
        /// A click or a slide happened, so the contact can no longer end as a tap.
        var isSpent = false
        /// A click happened, so the contact no longer slides either.
        var isCancelled = false
    }

    private let tuning: Tuning
    private var wasTouching = false
    /// The first finger's position on the previous sample, only while it was the single finger down.
    private var lastSingleFinger: TouchpadPoint?
    private var heldClickZone: TouchpadClickZone?
    private var twoFingerContact: TwoFingerContact?

    public init(tuning: Tuning = Tuning()) {
        self.tuning = tuning
    }

    /// Forgets everything seen so far and reports nothing.
    public mutating func reset() {
        wasTouching = false
        lastSingleFinger = nil
        heldClickZone = nil
        twoFingerContact = nil
    }

    /// Returns what happened between the previous sample and this one.
    public mutating func update(_ sample: TouchpadSample, at time: TimeInterval) -> [TouchpadEvent] {
        var events: [TouchpadEvent] = []
        let fingers = sample.fingerCount
        let isTouching = fingers > 0

        if isTouching, !wasTouching { events.append(.touchBegan) }

        if fingers == 2, twoFingerContact == nil, let midpoint = Self.midpoint(of: sample) {
            twoFingerContact = TwoFingerContact(startTime: time, startMidpoint: midpoint, slideAnchorY: midpoint.y)
        }

        appendClickEvents(for: sample, fingers: fingers, to: &events)
        appendTwoFingerEvents(for: sample, fingers: fingers, at: time, to: &events)
        appendMovement(for: sample, fingers: fingers, to: &events)

        if !isTouching, wasTouching { events.append(.touchEnded) }
        wasTouching = isTouching
        return events
    }

    // MARK: - Pieces

    private mutating func appendClickEvents(for sample: TouchpadSample, fingers: Int, to events: inout [TouchpadEvent]) {
        if sample.isClicked, heldClickZone == nil {
            let zone = Self.zone(for: sample, fingers: fingers)
            heldClickZone = zone
            events.append(.clickDown(zone))
            twoFingerContact?.isSpent = true
            twoFingerContact?.isCancelled = true
        } else if !sample.isClicked, let zone = heldClickZone {
            heldClickZone = nil
            events.append(.clickUp(zone))
        }
    }

    private mutating func appendTwoFingerEvents(
        for sample: TouchpadSample, fingers: Int, at time: TimeInterval, to events: inout [TouchpadEvent]
    ) {
        guard var contact = twoFingerContact else { return }

        guard fingers == 2, let midpoint = Self.midpoint(of: sample) else {
            /// A finger lifted: the contact is over.
            let wasQuick = time - contact.startTime <= tuning.tapMaxDuration
            if !contact.isSpent, wasQuick, contact.maxTravel <= tuning.tapMaxTravel {
                events.append(.twoFingerTap)
            }
            twoFingerContact = nil
            return
        }

        let dx = midpoint.x - contact.startMidpoint.x
        let dy = midpoint.y - contact.startMidpoint.y
        contact.maxTravel = max(contact.maxTravel, (dx * dx + dy * dy).squareRoot())

        if !contact.isCancelled, tuning.slideStepTravel > 0 {
            let steps = Int((midpoint.y - contact.slideAnchorY) / tuning.slideStepTravel)
            if steps != 0 {
                contact.slideAnchorY += Float(steps) * tuning.slideStepTravel
                contact.isSpent = true
                events.append(.twoFingerSlide(steps: steps))
            }
        }
        twoFingerContact = contact
    }

    private mutating func appendMovement(for sample: TouchpadSample, fingers: Int, to events: inout [TouchpadEvent]) {
        guard fingers == 1, let finger = sample.primary else {
            lastSingleFinger = nil
            return
        }
        if let last = lastSingleFinger {
            let dx = finger.x - last.x
            /// The pad's +y is up; the screen's is down.
            let dy = -(finger.y - last.y)
            if dx != 0 || dy != 0 { events.append(.moved(dx: dx, dy: dy)) }
        }
        lastSingleFinger = finger
    }

    private static func zone(for sample: TouchpadSample, fingers: Int) -> TouchpadClickZone {
        if fingers == 2 { return .twoFinger }
        guard let finger = sample.primary ?? sample.secondary else { return .left }
        return finger.x < 0 ? .left : .right
    }

    private static func midpoint(of sample: TouchpadSample) -> TouchpadPoint? {
        guard let first = sample.primary, let second = sample.secondary else { return nil }
        return TouchpadPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
