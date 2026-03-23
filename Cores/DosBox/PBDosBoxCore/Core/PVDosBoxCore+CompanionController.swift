// PVDosBoxCore+CompanionController.swift
// PVDosBox
//
// Extends PVDosBoxCore to adopt CompanionControllerCapable, routing companion
// keyboard and mouse events to the core's existing KeyboardResponder and
// MouseResponder implementations.
//
// Event flow:
//   CompanionInputRouter.keyboardMouseEvents
//     → PVEmulatorViewController (wired in issue #2707)
//       → PVDosBoxCore.companionKeyDown/Up / companionMouseMoved / companionMouseButton
//         → PVDosBoxCoreBridge keyboard/mouse methods (libretro pipeline)
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import PVCoreBridge
import GameController
import CoreGraphics
import ObjectiveC.runtime

// MARK: - Associated-object storage for cursor state

private final class MouseCursorState {
    /// Accumulated normalized cursor position, clamped to 0…1 on each axis.
    /// Initialized to centre so the first delta is relative to screen centre.
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
}

private var mouseStateKey: UInt8 = 0

private extension PVDosBoxCore {
    var mouseState: MouseCursorState {
        if let existing = objc_getAssociatedObject(self, &mouseStateKey) as? MouseCursorState {
            return existing
        }
        let state = MouseCursorState()
        objc_setAssociatedObject(self, &mouseStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }
}

// MARK: - CompanionControllerCapable

extension PVDosBoxCore: CompanionControllerCapable {

    // MARK: Keyboard

    /// Routes a companion key-down event to the core's `KeyboardResponder.keyDown(_:)`.
    @available(iOS 14.0, tvOS 14.0, *)
    public func companionKeyDown(_ key: GCKeyCode) {
        keyDown(key)
    }

    /// Routes a companion key-up event to the core's `KeyboardResponder.keyUp(_:)`.
    @available(iOS 14.0, tvOS 14.0, *)
    public func companionKeyUp(_ key: GCKeyCode) {
        keyUp(key)
    }

    // MARK: Mouse

    /// Accumulates the relative `delta` into a normalized cursor position (0…1) and
    /// forwards the result to `mouseMoved(atPoint:)`.
    ///
    /// `mouseMoved(atPoint:)` / `setMousePosition` expects a normalized absolute position,
    /// not a raw screen-point delta.  A sensitivity factor of 1/500 maps a 500-point drag
    /// to a full-width/height sweep; tune as needed.
    public func companionMouseMoved(delta: CGPoint) {
        let sensitivity: CGFloat = 1.0 / 500.0
        let state = mouseState
        let x = min(1, max(0, state.position.x + delta.x * sensitivity))
        let y = min(1, max(0, state.position.y + delta.y * sensitivity))
        state.position = CGPoint(x: x, y: y)
        mouseMoved(atPoint: state.position)
    }

    /// Routes a companion mouse button event to the core's left/right mouse responder methods.
    ///
    /// Passes the current tracked cursor position so the core does not warp to the origin.
    ///
    /// - Parameters:
    ///   - index: 0 = left button, 1 = right button (other indices are ignored).
    ///   - isDown: `true` on press, `false` on release.
    public func companionMouseButton(_ index: Int, isDown: Bool) {
        let currentPosition = mouseState.position
        switch index {
        case 0:   // Left mouse button
            if isDown {
                leftMouseDown(atPoint: currentPosition)
            } else {
                leftMouseUp()
            }
        case 1:   // Right mouse button
            if isDown {
                rightMouseDown(atPoint: currentPosition)
            } else {
                rightMouseUp()
            }
        default:
            break
        }
    }
}
