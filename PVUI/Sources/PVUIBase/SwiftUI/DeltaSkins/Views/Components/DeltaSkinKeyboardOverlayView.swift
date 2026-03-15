// DeltaSkinKeyboardOverlayView.swift
// PVUI
//
// SwiftUI wrapper that embeds the existing VirtualKeyboardView inside the
// DeltaSkin overlay stack.  The view owns a VirtualKeyboardViewModel,
// connects it to the DeltaSkinInputHandler (which implements
// VirtualKeyboardDelegate), and handles the top/bottom position hint from
// KeyboardOverlayConfig.
//
// tvOS: Not compiled — the delta-skin overlay is iOS/iPadOS only.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import GameController
import PVLogging

/// A SwiftUI view that renders a virtual keyboard overlay for skins that
/// declare a `keyboardOverlay` configuration in their `info.json`.
///
/// The view is only shown on iOS/iPadOS.  On tvOS the entire file is excluded.
///
/// Key design points:
/// - Reuses the existing `VirtualKeyboardView` / `VirtualKeyboardViewModel`
///   infrastructure so all layouts (full, compact, C64, etc.) come for free.
/// - Connects the view model's delegate to `DeltaSkinInputHandler`, which
///   implements `VirtualKeyboardDelegate` and forwards `GCKeyCode` events to
///   the emulator core via `KeyboardResponder`.
/// - Exposes a `isVisible` binding so the parent (`EmulatorWithSkinView`) can
///   toggle the overlay using the keyboard button it adds to the HUD.
/// - Respects `config.position` to anchor the overlay to the top or bottom.
/// - Forwards `config.opacity` to the view model (currently applied via the
///   existing sheet background).
public struct DeltaSkinKeyboardOverlayView: View {

    // MARK: - Inputs

    /// Skin-declared keyboard configuration.
    let config: KeyboardOverlayConfig

    /// Shared input handler that will receive key-down / key-up events.
    let inputHandler: DeltaSkinInputHandler

    /// Whether the overlay is visible.  Controlled by the parent view.
    @Binding var isVisible: Bool

    // MARK: - State

    @StateObject private var keyboardViewModel: VirtualKeyboardViewModel

    // MARK: - Init

    public init(
        config: KeyboardOverlayConfig,
        inputHandler: DeltaSkinInputHandler,
        isVisible: Binding<Bool>
    ) {
        self.config = config
        self.inputHandler = inputHandler
        self._isVisible = isVisible

        // Build the view model with the layout declared by the skin.
        let layout = config.variant.toLayout()
        self._keyboardViewModel = StateObject(
            wrappedValue: VirtualKeyboardViewModel(layout: layout)
        )
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { _ in
            if isVisible {
                VStack(spacing: 0) {
                    if config.position == .top {
                        keyboardContent
                        Spacer()
                    } else {
                        Spacer()
                        keyboardContent
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .onAppear {
            wireViewModel()
        }
        .onDisappear {
            keyboardViewModel.releaseAllKeys()
        }
        .onChange(of: isVisible) { newValue in
            if !newValue {
                keyboardViewModel.releaseAllKeys()
            }
        }
    }

    // MARK: - Keyboard sheet

    private var keyboardContent: some View {
        VirtualKeyboardView(viewModel: keyboardViewModel)
            .opacity(config.opacity)
    }

    // MARK: - Wiring

    private func wireViewModel() {
        // Connect delegate so key events reach the emulator.
        keyboardViewModel.delegate = inputHandler

        // Allow the X button inside VirtualKeyboardView to hide the overlay.
        keyboardViewModel.dismissAction = {
            isVisible = false
        }

        // Expand the keyboard immediately when the overlay first appears.
        // The view model boots collapsed; expand so the user sees keys.
        keyboardViewModel.isCollapsed = false
    }
}

// MARK: - Preview

#if DEBUG
struct DeltaSkinKeyboardOverlayView_Previews: PreviewProvider {
    @State static var visible = true

    static var previews: some View {
        let config = KeyboardOverlayConfig(
            variant: .full,
            autoShow: true,
            position: .bottom,
            opacity: 0.9
        )
        let handler = DeltaSkinInputHandler()

        ZStack {
            Color.black.ignoresSafeArea()
            DeltaSkinKeyboardOverlayView(
                config: config,
                inputHandler: handler,
                isVisible: $visible
            )
        }
        .previewDisplayName("Full QWERTY – bottom")
    }
}
#endif
#endif // !os(tvOS)
