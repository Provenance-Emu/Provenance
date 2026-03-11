// VirtualKeyboardViewModel.swift
// PVUI
//
// Observable view model that tracks modifier key state and forwards
// key events to the emulator core via the KeyboardResponder protocol.
//
// Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(tvOS)
import Foundation
import Combine
import GameController
import PVCoreBridge
import PVSettings

// MARK: - VirtualKeyboardDelegate

/// Receives key-down / key-up events from the virtual keyboard.
public protocol VirtualKeyboardDelegate: AnyObject {
    @available(iOS 14.0, *)
    func virtualKeyboard(_ keyboard: VirtualKeyboardViewModel, keyDown keyCode: GCKeyCode)
    @available(iOS 14.0, *)
    func virtualKeyboard(_ keyboard: VirtualKeyboardViewModel, keyUp keyCode: GCKeyCode)
}

// MARK: - VirtualKeyboardViewModel

/// Manages the state of the virtual keyboard overlay:
/// active modifier keys, the dismiss callback, and event forwarding.
@MainActor
public final class VirtualKeyboardViewModel: ObservableObject {

    // MARK: - Published state

    /// The currently active keyboard layout.
    @Published public var layout: VirtualKeyboardLayout = .full

    /// Whether the keyboard panel is collapsed to just the drag handle.
    ///
    /// Defaults to `true` so the overlay boots in a minimal footprint.
    /// The user can expand it by tapping the handle or pressing the chevron button.
    @Published public var isCollapsed: Bool = true

    /// Keys currently held down (by HID code).
    @Published public private(set) var heldKeys: Set<GCKeyCode> = []

    /// Sticky modifier states (toggle on first press, clear on second).
    @Published public private(set) var activeModifiers: Set<GCKeyCode> = []

    /// Whether Caps Lock is currently engaged.
    @Published public private(set) var capsLockOn: Bool = false

    /// Whether shift is active (from left or right shift sticky or held).
    public var isShiftActive: Bool {
        activeModifiers.contains(.leftShift) || activeModifiers.contains(.rightShift)
    }

    /// Effective uppercase: shift XOR caps lock.
    public var isUppercase: Bool {
        isShiftActive != capsLockOn
    }

    // MARK: - Callbacks

    /// Called when the user fully dismisses the overlay (X button).
    public var dismissAction: (() -> Void)?

    // MARK: - Delegate

    public weak var delegate: VirtualKeyboardDelegate?

    // MARK: - Init

    public init(delegate: VirtualKeyboardDelegate? = nil, layout: VirtualKeyboardLayout = .full) {
        self.delegate = delegate
        self.layout = layout
    }

    // MARK: - Layout

    /// Switch to a new layout, releasing all held modifiers first.
    /// Persists the choice to `preferredKeyboardVariant` so it is restored next session.
    public func selectLayout(_ newLayout: VirtualKeyboardLayout) {
        releaseAllKeys()
        layout = newLayout
        Defaults[.preferredKeyboardVariant] = newLayout.rawValue
    }

    // MARK: - Key events

    /// Called on touch-begin for a key.
    public func keyDown(_ key: VirtualKey) {
        if key.isModifier {
            handleModifierDown(key)
        } else {
            if #available(iOS 14.0, *) {
                if !heldKeys.contains(key.keyCode) {
                    heldKeys.insert(key.keyCode)
                    delegate?.virtualKeyboard(self, keyDown: key.keyCode)
                }
            }
        }
    }

    /// Called on touch-end for a key.
    public func keyUp(_ key: VirtualKey) {
        if key.isModifier {
            // Modifier "up" is a no-op for sticky keys — they stay until toggled again.
            return
        }
        if #available(iOS 14.0, *) {
            heldKeys.remove(key.keyCode)
            delegate?.virtualKeyboard(self, keyUp: key.keyCode)

            // Auto-release one-shot shift after a regular key is typed.
            releaseOneshotShift()
        }
    }

    // MARK: - Cleanup

    /// Release all currently held keys — call on view teardown to prevent stuck keys.
    public func releaseAllKeys() {
        if #available(iOS 14.0, *) {
            for code in heldKeys {
                delegate?.virtualKeyboard(self, keyUp: code)
            }
            heldKeys.removeAll()

            for code in activeModifiers {
                delegate?.virtualKeyboard(self, keyUp: code)
            }
            activeModifiers.removeAll()

            if capsLockOn {
                delegate?.virtualKeyboard(self, keyUp: .capsLock)
                capsLockOn = false
            }
        }
    }

    // MARK: - Private helpers

    private func handleModifierDown(_ key: VirtualKey) {
        if key.keyCode == .capsLock {
            capsLockOn.toggle()
            if #available(iOS 14.0, *) {
                if capsLockOn {
                    delegate?.virtualKeyboard(self, keyDown: .capsLock)
                } else {
                    delegate?.virtualKeyboard(self, keyUp: .capsLock)
                }
            }
            return
        }

        // Toggle sticky modifier
        if activeModifiers.contains(key.keyCode) {
            activeModifiers.remove(key.keyCode)
            if #available(iOS 14.0, *) {
                delegate?.virtualKeyboard(self, keyUp: key.keyCode)
            }
        } else {
            activeModifiers.insert(key.keyCode)
            if #available(iOS 14.0, *) {
                delegate?.virtualKeyboard(self, keyDown: key.keyCode)
            }
        }
    }

    /// After a regular keypress, release shift if it was a one-shot sticky press.
    private func releaseOneshotShift() {
        let shiftCodes: [GCKeyCode] = [.leftShift, .rightShift]
        for code in shiftCodes {
            if activeModifiers.contains(code) {
                activeModifiers.remove(code)
                if #available(iOS 14.0, *) {
                    delegate?.virtualKeyboard(self, keyUp: code)
                }
            }
        }
    }
}
#endif // !os(tvOS)
