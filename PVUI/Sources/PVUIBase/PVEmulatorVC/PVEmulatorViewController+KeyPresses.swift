// PVEmulatorViewController+KeyPresses.swift
// PVUI
//
// Consumes UIKit key-press events for keys that are already mapped to game
// input via the virtual `GCKeyboard` controller (see
// `PVControllerManager.buildKeyboardController()`).
//
// ROOT CAUSE (macOS "Designed for iPad"): the app reads the keyboard through
// GameController's `GCKeyboard`, which *observes* key state but never marks
// the underlying UIKit `UIPress` events as handled. `PVEmulatorViewController`
// never overrode `pressesBegan`/`pressesEnded`/`pressesCancelled` and declared
// no `keyCommands`, so every keypress travelled the full responder chain
// unhandled. AppKit answers any unhandled key event on a Mac with the system
// alert beep — so every mapped gameplay key beeped on every press.
//
// This file's only job is to swallow presses whose key is currently bound in
// `KeyboardControllerMap` so they stop propagating past this controller. It
// does NOT synthesize or forward button presses to the core — `GCKeyboard`'s
// existing observation already delivers that input; duplicating it here would
// double-fire.
//
// iOS only: on tvOS, `PVEmulatorViewController`'s root class is
// `GCEventViewController` (see `PVEmulatorViewControllerRootClass` in
// PVEmulatorViewController.swift), which already owns Siri Remote press
// routing into the GameController stack. There is no macOS/AppKit responder
// chain on tvOS, so there is no beep to fix there, and layering another
// pressesBegan override on top of GCEventViewController's own risks
// interfering with Siri Remote handling for no benefit. Scoped to `os(iOS)`.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if os(iOS)
import UIKit
import GameController

@MainActor
extension PVEmulatorViewController {

    /// Modifier flags that must always be forwarded to `super` untouched so
    /// system shortcuts (⌘Q, ⌘S, ⌘L, ⇧⌘M, the whole menu bar) keep working.
    /// Shift alone is intentionally NOT included: the default keyboard map
    /// binds right-Shift to Start and left-Shift to L2, so plain Shift is
    /// legitimate mapped gameplay input, not a modifier combo to protect.
    private static let guardedModifierFlags: UIKeyModifierFlags = [.command, .alternate]

    /// The set of `GCKeyCode`s currently bound to any controller action in the
    /// active `KeyboardControllerMap`. Read fresh each time presses arrive
    /// (cheap: ~24 actions, 1-2 keys each) so remaps made mid-session via the
    /// keyboard HUD / remap UI take effect immediately.
    private var mappedKeyCodes: Set<GCKeyCode> {
        let map = KeyboardControllerMap.current
        return Set(KeyboardControllerAction.allCases.flatMap { map.keys(for: $0) })
    }

    /// True when `press` should be forwarded to `super` untouched rather than
    /// consumed: desktop input mode is off (no virtual keyboard controller
    /// exists to have generated gameplay input for it), the press carries a
    /// guarded modifier, or the key simply isn't bound to any controller
    /// action.
    private func shouldForward(_ press: UIPress, event: UIPressesEvent?, mappedKeyCodes: Set<GCKeyCode>) -> Bool {
        guard GamepadManager.isDesktopInputMode else { return true }

        let flags = press.key?.modifierFlags ?? event?.modifierFlags ?? []
        guard flags.isDisjoint(with: Self.guardedModifierFlags) else { return true }

        // `GCKeyCode` and `UIKeyboardHIDUsage` both wrap the same USB HID
        // "Keyboard/Keypad Page" usage IDs, so the raw integer value carries
        // across directly - this is the standard bridge between the two.
        guard let hidUsage = press.key?.keyCode else { return true }
        let keyCode = GCKeyCode(rawValue: hidUsage.rawValue)
        return !mappedKeyCodes.contains(keyCode)
    }

    /// Filters `presses` down to the subset that should reach `super`, using
    /// `shouldForward(_:event:mappedKeyCodes:)`. Returns `nil` when nothing
    /// should be forwarded. Not calling `super` for the consumed presses is
    /// what stops them propagating further up the responder chain (and, on a
    /// Mac, stops the beep).
    private func filterForwardablePresses(_ presses: Set<UIPress>, with event: UIPressesEvent?) -> Set<UIPress>? {
        guard GamepadManager.isDesktopInputMode else { return presses }

        let mapped = mappedKeyCodes
        let forwarded = presses.filter { shouldForward($0, event: event, mappedKeyCodes: mapped) }
        return forwarded.isEmpty ? nil : forwarded
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let forwarded = filterForwardablePresses(presses, with: event) else { return }
        super.pressesBegan(forwarded, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let forwarded = filterForwardablePresses(presses, with: event) else { return }
        super.pressesEnded(forwarded, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let forwarded = filterForwardablePresses(presses, with: event) else { return }
        super.pressesCancelled(forwarded, with: event)
    }
}
#endif // os(iOS)
