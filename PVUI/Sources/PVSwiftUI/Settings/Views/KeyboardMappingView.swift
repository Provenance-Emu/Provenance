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
                    map = .standard
                    map.save()
                    rebuildKeyboardController()
                }
            }
        }
        .navigationTitle("Keyboard Mapping")
        .onDisappear { endCapture() }
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
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else { return }
        endCapture()
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

    private func endCapture() {
        if let saved = savedKeyHandler {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = saved
            savedKeyHandler = nil
        }
        capturingAction = nil
    }

    /// Recreate the virtual keyboard controller so the new bindings take effect.
    private func rebuildKeyboardController() {
        PVControllerManager.shared.handleKeyboardDisconnect(nil)
        PVControllerManager.shared.handleKeyboardConnect(nil)
    }
}
#endif
