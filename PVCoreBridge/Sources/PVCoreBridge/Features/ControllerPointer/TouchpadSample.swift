//
//  TouchpadSample.swift
//  PVCoreBridge
//
//  One reading of a controller's touchpad (DualSense, DualShock 4).
//

import Foundation

/// A finger position on a controller touchpad, in the pad's own units:
/// -1 to 1 on each axis, with +y towards the top of the pad.
public struct TouchpadPoint: Equatable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// The state of a controller touchpad at one instant.
public struct TouchpadSample: Equatable, Sendable {
    /// The first finger, or nil when it is not on the pad.
    public var primary: TouchpadPoint?
    /// The second finger, or nil when it is not on the pad.
    public var secondary: TouchpadPoint?
    /// Whether the pad is pressed down (its click).
    public var isClicked: Bool

    public init(primary: TouchpadPoint? = nil, secondary: TouchpadPoint? = nil, isClicked: Bool = false) {
        self.primary = primary
        self.secondary = secondary
        self.isClicked = isClicked
    }

    /// Builds a sample from the raw axis values GameController reports.
    ///
    /// GameController has no "finger down" flag: a lifted finger reads exactly (0, 0).
    /// A finger resting on the exact centre is therefore indistinguishable from a lifted
    /// one and is treated as lifted; `TouchpadGestureRecognizer` never produces movement
    /// across such a gap.
    public init(primaryX: Float, primaryY: Float, secondaryX: Float, secondaryY: Float, isClicked: Bool) {
        self.primary = Self.point(x: primaryX, y: primaryY)
        self.secondary = Self.point(x: secondaryX, y: secondaryY)
        self.isClicked = isClicked
    }

    /// How many fingers are on the pad.
    public var fingerCount: Int {
        (primary == nil ? 0 : 1) + (secondary == nil ? 0 : 1)
    }

    private static func point(x: Float, y: Float) -> TouchpadPoint? {
        x == 0 && y == 0 ? nil : TouchpadPoint(x: x, y: y)
    }
}

/// Where the pad was pressed.
public enum TouchpadClickZone: String, Codable, Sendable, CaseIterable {
    /// One finger on the left half, or a press with no finger reading.
    case left
    /// One finger on the right half.
    case right
    /// Two fingers on the pad.
    case twoFinger
}

/// Something the player did on the touchpad.
public enum TouchpadEvent: Equatable, Sendable {
    /// A finger landed on an empty pad.
    case touchBegan
    /// The last finger left the pad.
    case touchEnded
    /// One finger moved. Pad units; `dy` is positive towards the bottom of the screen.
    case moved(dx: Float, dy: Float)
    case clickDown(TouchpadClickZone)
    case clickUp(TouchpadClickZone)
    /// Two fingers touched and left quickly without moving or clicking.
    case twoFingerTap
    /// Two fingers slid vertically. Positive steps are towards the top of the pad.
    case twoFingerSlide(steps: Int)
}
