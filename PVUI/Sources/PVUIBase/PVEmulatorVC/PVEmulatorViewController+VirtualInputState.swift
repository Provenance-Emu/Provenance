///
/// PVEmulatorViewController+VirtualInputState.swift
/// PVUIBase
///
/// Cross-platform (iOS + tvOS) home for the `virtualInputState` property and
/// the core capability-check helpers that both platforms need.
///
/// By keeping this extension free of any `#if os(tvOS)` / `#if !os(tvOS)` guard
/// we ensure that:
///   - tvOS Siri Remote keyboard/mouse handlers can update the same state object
///     as their iOS counterparts.
///   - Future tvOS UI (pause menu, status indicator) can consume the state via
///     `@EnvironmentObject var state: VirtualInputState` using the same pattern
///     as iOS.
///
/// Copyright © 2026 Provenance Emu. All rights reserved.
///

import Foundation
import PVCoreBridge

// MARK: - Associated-object key

private enum VISKeys {
    static var virtualInputState: UInt8 = 0
}

// MARK: - PVEmulatorViewController + VirtualInputState

@MainActor
extension PVEmulatorViewController {

    // MARK: - Shared state object

    /// The observable state object that drives virtual-input overlay UI on both
    /// iOS and tvOS.
    ///
    /// Created lazily on first access (after `core` is available).  The same
    /// instance is reused for the lifetime of the session.  Inject it into the
    /// SwiftUI environment via `.environmentObject(virtualInputState)`.
    public var virtualInputState: VirtualInputState {
        if let existing = objc_getAssociatedObject(self, &VISKeys.virtualInputState)
                            as? VirtualInputState {
            return existing
        }
        let state = VirtualInputState(
            supportsKeyboard: coreSupportsVirtualKeyboard,
            supportsMouse: coreSupportsVirtualMouse
        )
        objc_setAssociatedObject(
            self, &VISKeys.virtualInputState,
            state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return state
    }

    // MARK: - Capability checks (cross-platform)

    /// Whether the emulator core reports keyboard support.
    public var coreSupportsVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.gameSupportsKeyboard == true
    }

    /// Whether the emulator core reports mouse support.
    public var coreSupportsVirtualMouse: Bool {
        (core as? MouseResponder)?.gameSupportsMouse == true
    }
}
