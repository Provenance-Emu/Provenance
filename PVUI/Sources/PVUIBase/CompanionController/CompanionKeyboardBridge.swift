// CompanionKeyboardBridge.swift
// PVUI
//
// Bridges VirtualKeyboardDelegate callbacks to CompanionInputRouter events,
// routing keyboard key presses from the companion device into the emulator core
// via the CompanionInputRouter's keyboardMouseEvents publisher.
//
// Usage:
//   let bridge = CompanionKeyboardBridge(inputRouter: router)
//   keyboardVM.delegate = bridge   // sets weak ref; keep bridge alive via @StateObject
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Combine
import GameController

// MARK: - CompanionKeyboardBridge

/// Converts `VirtualKeyboardDelegate` key callbacks into `CompanionInputEvent.keyDown/keyUp`
/// events forwarded through the shared `CompanionInputRouter`.
///
/// `DOSKeyboardLayout` owns this bridge as a `@StateObject` so it outlives the
/// `VirtualKeyboardViewModel` that holds a `weak` reference to it as its `delegate`.
/// All methods are called on the main actor, matching `VirtualKeyboardViewModel`'s context.
@MainActor
public final class CompanionKeyboardBridge: ObservableObject {

    // MARK: - Private

    private let inputRouter: CompanionInputRouter

    // MARK: - Init

    public init(inputRouter: CompanionInputRouter) {
        self.inputRouter = inputRouter
    }
}

// MARK: - VirtualKeyboardDelegate

extension CompanionKeyboardBridge: VirtualKeyboardDelegate {

    /// Forwards a key-down event from the on-screen keyboard to the companion router.
    @available(iOS 14.0, *)
    public func virtualKeyboard(_ keyboard: VirtualKeyboardViewModel, keyDown keyCode: GCKeyCode) {
        inputRouter.send(.keyDown(keyCode))
    }

    /// Forwards a key-up event from the on-screen keyboard to the companion router.
    @available(iOS 14.0, *)
    public func virtualKeyboard(_ keyboard: VirtualKeyboardViewModel, keyUp keyCode: GCKeyCode) {
        inputRouter.send(.keyUp(keyCode))
    }
}

#endif // !os(tvOS)
