///
/// VirtualInputState.swift
/// PVUIBase
///
/// Single source of truth for virtual keyboard and mouse-cursor overlay state.
///
/// Replaces the previous NSNotification-based synchronisation with type-safe,
/// directly-observed `@Published` properties and closure-based toggle actions.
///
/// Ownership & injection
/// ----------------------
/// `PVEmulatorViewController` creates and owns one `VirtualInputState` instance
/// per emulation session.  The instance is injected into the SwiftUI view
/// hierarchy via `.environmentObject(_:)` so that overlay views can observe
/// state changes reactively without any coupling to the view controller.
///
/// UIKit code (e.g. `PVControllerViewController`) can subscribe to changes via
/// Combine (`$isKeyboardVisible.sink { … }`).
///
/// Copyright © 2026 Provenance Emu. All rights reserved.
///

import Foundation
import Combine

// MARK: - VirtualInputState

/// Observable state container for virtual input overlays.
///
/// - `isKeyboardVisible` / `isMouseVisible` — updated by `PVEmulatorViewController`
///   whenever an overlay is shown or hidden; SwiftUI views subscribe automatically.
/// - `onToggleKeyboard` / `onToggleMouse` — closures wired to
///   `PVEmulatorViewController.toggleVirtualKeyboard()` /
///   `PVEmulatorViewController.toggleVirtualMouse()` so SwiftUI buttons can
///   trigger the toggle without a direct view-controller reference.
@MainActor
public final class VirtualInputState: ObservableObject {

    // MARK: - Observed visibility state

    /// `true` while the virtual keyboard overlay is on screen.
    @Published public private(set) var isKeyboardVisible: Bool = false

    /// `true` while the virtual mouse cursor overlay is on screen.
    @Published public private(set) var isMouseVisible: Bool = false

    // MARK: - Static capability flags (read once at init)

    /// Whether the active emulator core supports virtual keyboard input.
    public let supportsKeyboard: Bool

    /// Whether the active emulator core supports virtual mouse input.
    public let supportsMouse: Bool

    // MARK: - Action callbacks (wired by PVEmulatorViewController)

    /// Invoked when the user taps the keyboard toggle button.
    /// Wired by `PVEmulatorViewController` to `toggleVirtualKeyboard()`.
    public var onToggleKeyboard: () -> Void = {}

    /// Invoked when the user taps the mouse toggle button.
    /// Wired by `PVEmulatorViewController` to `toggleVirtualMouse()`.
    public var onToggleMouse: () -> Void = {}

    // MARK: - Initialiser

    public init(supportsKeyboard: Bool, supportsMouse: Bool) {
        self.supportsKeyboard = supportsKeyboard
        self.supportsMouse = supportsMouse
    }

    // MARK: - State mutators (called by PVEmulatorViewController)

    /// Update the keyboard-overlay visibility flag.  Must be called on the main actor.
    public func setKeyboardVisible(_ visible: Bool) {
        isKeyboardVisible = visible
    }

    /// Update the mouse-overlay visibility flag.  Must be called on the main actor.
    public func setMouseVisible(_ visible: Bool) {
        isMouseVisible = visible
    }
}
