import Foundation
import CoreGraphics

/// A skin control whose hit area contains the current touch. A plain value so the selection rules can be
/// tested without a view.
public struct SkinTouchCandidate: Equatable, Sendable {
    /// Caller-defined identity (the skin button id).
    public let id: String
    /// The input token this control presses.
    public let command: String
    /// Distance from the touch to the control's centre, in view points.
    public let distance: CGFloat
    /// Directional group (d-pad style).
    public let isDPad: Bool
    public let isThumbstick: Bool
    public let role: TouchInputRole

    public init(id: String, command: String, distance: CGFloat, isDPad: Bool, isThumbstick: Bool,
                role: TouchInputRole) {
        self.id = id
        self.command = command
        self.distance = distance
        self.isDPad = isDPad
        self.isThumbstick = isThumbstick
        self.role = role
    }

    /// D-pads and sticks are gameplay whatever their token says.
    public var allowsSlideIn: Bool { isDPad || isThumbstick || role.isGameplay }

    /// Plain press-and-release gameplay button: the only kind that joins a multi-button press.
    public var isMultiPressEligible: Bool { !isDPad && !isThumbstick && role.isGameplay }
}

/// What a touch acts on.
public struct SkinTouchResolution: Equatable, Sendable {
    /// The winner under the closest-wins rule (nil: the touch is on nothing it may press).
    public let primary: SkinTouchCandidate?
    /// Plain buttons the touch holds. Empty when the winner is a d-pad or a stick (their own handlers
    /// drive those).
    public let pressed: [SkinTouchCandidate]
    /// True when the touch went down on a system control: it is latched to that control from now on.
    public let latchesToSystem: Bool

    public var commands: Set<String> { Set(pressed.map(\.command)) }
}

/// What to do with a touch that is already down when it reports a new location.
public enum SkinTouchContinuation: Equatable, Sendable {
    /// The touch still holds what it held; change nothing.
    case keep
    /// The touch began on a system control and has left it: release what it holds and press nothing,
    /// now and for the rest of the touch.
    case releaseAndIgnore
    /// Release what the touch no longer covers and resolve the candidates at the new location.
    case resolve
}

/// Touch rules for Delta / Manic skins, ported from iFly.
///
/// - Drag across: a moving touch releases the button it left and presses the gameplay button it reached.
/// - Multi-button touch (fat finger): with `multiButton`, a touch whose winner is a plain gameplay button
///   also presses every other plain gameplay button whose hit area contains it.
/// - Lockout: system controls (menu, save / load, fast-forward, screenshot, switches...) are pressed only
///   by a touch that begins on them, are never added by multi-button touch, and a touch that began on one
///   is latched to it.
public enum SkinTouchSelection {
    /// Closest wins; a d-pad beats a regular button unless the button is less than half as far away.
    public static func sortedByPreference(_ candidates: [SkinTouchCandidate]) -> [SkinTouchCandidate] {
        candidates.sorted { first, second in
            if first.isDPad == second.isDPad { return first.distance < second.distance }
            if first.isDPad { return second.distance > first.distance * 2 }
            return first.distance < second.distance * 2
        }
    }

    /// Resolves a touch against the controls under it.
    ///
    /// - `isTouchBegin` false (the touch slid here): system candidates are dropped before anything is
    ///   chosen, so a slide can never reach one.
    /// - Single mode: only the winner acts.
    /// - Multi mode: when the winner is a plain gameplay button, every plain gameplay candidate acts. A
    ///   d-pad, stick or system winner acts alone.
    public static func resolve(_ candidates: [SkinTouchCandidate], multiButton: Bool,
                               isTouchBegin: Bool) -> SkinTouchResolution {
        let reachable = isTouchBegin ? candidates : candidates.filter(\.allowsSlideIn)
        let sorted = sortedByPreference(reachable)
        guard let primary = sorted.first else {
            return SkinTouchResolution(primary: nil, pressed: [], latchesToSystem: false)
        }
        if primary.isDPad || primary.isThumbstick {
            return SkinTouchResolution(primary: primary, pressed: [], latchesToSystem: false)
        }
        let latches = isTouchBegin && !primary.role.isGameplay
        guard multiButton, primary.isMultiPressEligible else {
            return SkinTouchResolution(primary: primary, pressed: [primary], latchesToSystem: latches)
        }
        return SkinTouchResolution(primary: primary, pressed: sorted.filter(\.isMultiPressEligible),
                                   latchesToSystem: false)
    }

    /// Decides how a moving touch that already holds buttons continues.
    ///
    /// - Parameters:
    ///   - holdsButtons: the touch currently holds at least one plain button.
    ///   - stillOnHeld: the touch is still inside the hit area of the button it holds.
    ///   - isLatched: the touch began on a system control.
    public static func continuation(holdsButtons: Bool, stillOnHeld: Bool, isLatched: Bool,
                                    multiButton: Bool) -> SkinTouchContinuation {
        // Single-button mode keeps a touch on its button while it stays inside it (no flicker between two
        // overlapping hit areas). Multi-button mode re-derives the held set on every move so a rolling
        // finger can add and drop buttons; a latched touch keeps the sticky rule in both modes.
        if holdsButtons, stillOnHeld, !multiButton || isLatched { return .keep }
        if isLatched { return .releaseAndIgnore }
        return .resolve
    }
}
