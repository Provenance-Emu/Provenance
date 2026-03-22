// CompanionControllerCapable.swift
// PVCoreBridge
//
// Protocol adopted by emulator cores that can receive keyboard and mouse input
// directly from a companion controller session.
//
// Flow (wired in issue #2707):
//   CompanionInputRouter.keyboardMouseEvents (Publisher<CompanionInputEvent>)
//     → PVEmulatorViewController subscriber
//       → core.companionKeyDown / companionKeyUp / companionMouseMoved / companionMouseButton
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import CoreGraphics

#if canImport(GameController)
import GameController
#endif

// MARK: - CompanionControllerCapable

/// Adopted by emulator cores that handle keyboard and/or mouse input from a
/// companion controller session.
///
/// The emulator view controller calls these methods on the main thread when
/// keyboard or mouse events arrive from the companion device.
///
/// Cores that support only keyboard should return empty implementations for the
/// mouse methods (and vice versa).
///
/// Example — DOS core keyboard forwarding:
/// ```swift
/// extension PVDosBoxCore: CompanionControllerCapable {
///     public func companionKeyDown(_ key: GCKeyCode) { keyDown(key) }
///     public func companionKeyUp(_ key: GCKeyCode)   { keyUp(key) }
///     public func companionMouseMoved(delta: CGPoint) { mouseMoved(atPoint: delta) }
///     public func companionMouseButton(_ index: Int, isDown: Bool) { ... }
/// }
/// ```
public protocol CompanionControllerCapable: AnyObject {

    // MARK: - Keyboard

#if canImport(GameController)
    /// A companion keyboard key was pressed.
    /// - Parameter key: HID USB key code (matches `GCKeyCode.rawValue`).
    @available(iOS 14.0, tvOS 14.0, *)
    func companionKeyDown(_ key: GCKeyCode)

    /// A companion keyboard key was released.
    /// - Parameter key: HID USB key code.
    @available(iOS 14.0, tvOS 14.0, *)
    func companionKeyUp(_ key: GCKeyCode)
#endif

    // MARK: - Mouse

    /// The companion trackpad sent a relative movement delta.
    /// - Parameter delta: Movement in points relative to the last reported position.
    ///   Components can be positive or negative. The emulator core maps this to its
    ///   internal mouse coordinate system.
    func companionMouseMoved(delta: CGPoint)

    /// A companion mouse button state changed.
    /// - Parameters:
    ///   - index: Button index. 0 = left, 1 = right, 2 = middle.
    ///   - isDown: `true` on press; `false` on release.
    func companionMouseButton(_ index: Int, isDown: Bool)
}
