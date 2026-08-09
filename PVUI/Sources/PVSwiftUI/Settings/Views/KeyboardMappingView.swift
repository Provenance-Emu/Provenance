//
//  KeyboardMappingView.swift
//  PVUI
//
//  Settings screen for remapping keyboard keys to virtual controller buttons.
//  Displayed in Settings → Controller → Keyboard Mapping.
//

import SwiftUI
import GameController
import PVUIBase
import PVThemes

/// Lists every keyboard-controller action with its bound keys; tap a row then press
/// a key to rebind. iOS/Catalyst-style desktop feature; excluded from tvOS.
#if !os(tvOS)
public struct KeyboardMappingView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var map = KeyboardControllerMap.current
    @State private var capturingAction: KeyboardControllerAction?
    @State private var savedKeyHandler: GCKeyboardValueChangedHandler?

    public init() {}

    public var body: some View {
        List {
            SwiftUI.Section(footer: Text("Tap an action, then press a key to rebind. Press Delete to clear back to default.")) {
                ForEach(KeyboardControllerAction.allCases, id: \.rawValue) { action in
                    Button {
                        beginCapture(for: action)
                    } label: {
                        HStack {
                            Text(action.displayName)
                            Spacer()
                            Text(capturingAction == action ? "Press a key…" : keyNames(for: action))
                                .foregroundColor(capturingAction == action
                                                 ? themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
                                                 : .secondary)
                        }
                    }
                }
            }
            SwiftUI.Section {
                Button("Reset All to Defaults", role: .destructive) {
                    // Abort any in-progress capture BEFORE tearing down the virtual
                    // controller — otherwise the capture closure keeps a dangling
                    // reference to the pre-reset controller (see abortCaptureForHardwareChange).
                    endCapture()
                    map = .standard
                    map.save()
                    rebuildKeyboardController()
                }
            }
        }
        .navigationTitle("Keyboard Mapping")
        .onDisappear { endCapture() }
        // The virtual controller (and its keyChangedHandler) is rebuilt by
        // PVControllerManager whenever the physical keyboard set changes — a real
        // disconnect, or a second keyboard connecting without an intervening disconnect
        // (handleKeyboardConnect reassigns `keyboardController` unconditionally). Either
        // event means any handler we saved before capture began is now stale; abort
        // instead of restoring it. See abortCaptureForHardwareChange for details.
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect).receive(on: DispatchQueue.main)) { _ in
            abortCaptureForHardwareChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect).receive(on: DispatchQueue.main)) { _ in
            abortCaptureForHardwareChange()
        }
    }

    private func keyNames(for action: KeyboardControllerAction) -> String {
        let keys = map.keys(for: action)
        guard !keys.isEmpty else { return "—" }
        return keys.map { keyName($0) }.joined(separator: ", ")
    }

    private func keyName(_ code: GCKeyCode) -> String {
        // GCKeyboardInput buttons carry readable names via their aliases/localizedName.
        if let button = GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: code),
           let name = button.aliases.first ?? button.localizedName {
            return name
        }
        return "Key \(code.rawValue)"
    }

    private func beginCapture(for action: KeyboardControllerAction) {
        // Unconditionally end any prior capture first (cheap/idempotent when nothing was
        // capturing) so a stale capture never survives past the point a new one starts,
        // even if `keyboardInput` below turns out nil (e.g. keyboard vanished between taps).
        endCapture()
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else { return }
        capturingAction = action
        savedKeyHandler = keyboardInput.keyChangedHandler
        keyboardInput.keyChangedHandler = { _, _, keyCode, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                if keyCode == .deleteOrBackspace {
                    map.set(keys: KeyboardControllerMap.standard.keys(for: action), for: action)
                } else {
                    map.set(keys: [keyCode], for: action)
                }
                map.save()
                endCapture()
                rebuildKeyboardController()
            }
        }
    }

    /// Ends capture normally: the keyboard hardware hasn't changed since capture began, so
    /// whatever handler we saved beforehand is still the correct thing to restore.
    private func endCapture() {
        if let saved = savedKeyHandler {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = saved
            savedKeyHandler = nil
        }
        capturingAction = nil
    }

    /// Aborts an in-progress capture because the keyboard hardware changed underneath us —
    /// disconnected, or a second keyboard connected without an intervening disconnect.
    /// PVControllerManager has already replaced or torn down `keyChangedHandler` itself in
    /// response (see PVControllerManager.handleKeyboardConnect/handleKeyboardDisconnect), so
    /// `savedKeyHandler` — bound to the now-gone-or-superseded virtual controller — must be
    /// discarded rather than written back. Writing it back would silently kill keyboard
    /// input app-wide: the restored closure captures a `gamepad` from a `GCController`
    /// PVControllerManager no longer tracks, so every subsequent keystroke would drive an
    /// orphaned controller nothing observes. The connect/disconnect cycle that triggered
    /// this installs a correct fresh handler on its own; nothing further to do here beyond
    /// clearing our own local capture state (which also fixes the row UI staying stuck on
    /// "Press a key…").
    private func abortCaptureForHardwareChange() {
        guard capturingAction != nil else { return }
        savedKeyHandler = nil
        capturingAction = nil
    }

    /// Recreate the virtual keyboard controller so the new bindings take effect.
    private func rebuildKeyboardController() {
        PVControllerManager.shared.rebuildKeyboardController()
    }
}
#endif
