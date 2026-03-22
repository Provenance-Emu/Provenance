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

    /// Routes a companion trackpad delta to the core's `MouseResponder.mouseMoved(atPoint:)`.
    ///
    /// The companion trackpad already computes relative deltas, so the value is forwarded
    /// directly without coordinate transformation.
    public func companionMouseMoved(delta: CGPoint) {
        mouseMoved(atPoint: delta)
    }

    /// Routes a companion mouse button event to the core's left/right mouse responder methods.
    ///
    /// - Parameters:
    ///   - index: 0 = left button, 1 = right button (other indices are ignored).
    ///   - isDown: `true` on press, `false` on release.
    public func companionMouseButton(_ index: Int, isDown: Bool) {
        switch index {
        case 0:   // Left mouse button
            if isDown {
                leftMouseDown(atPoint: .zero)
            } else {
                leftMouseUp()
            }
        case 1:   // Right mouse button
            if isDown {
                rightMouseDown(atPoint: .zero)
            } else {
                rightMouseUp()
            }
        default:
            break
        }
    }
}
