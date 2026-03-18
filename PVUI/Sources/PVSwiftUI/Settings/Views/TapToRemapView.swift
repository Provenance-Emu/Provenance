//
//  TapToRemapView.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #705 — tap-to-remap UX (feature-flagged, default OFF)
//
//  This view listens for a physical controller button press and uses
//  the pressed button as the destination in a button remapping.
//  Gated behind the `tapToRemapUI` feature flag so it can be developed
//  independently without affecting default remapping behaviour.
//

import SwiftUI
import GameController
import PVUIBase
import PVLogging

// MARK: - TapToRemapView

/// A full-screen sheet that listens for a single physical button press on a
/// `GCController` and calls `onCapture` with the detected `ButtonIdentifier`.
///
/// - The sheet temporarily installs a `valueChangedHandler` on the controller's
///   `extendedGamepad` while it is visible.  The handler is removed on dismiss,
///   restoring normal remapping behaviour.
/// - Safe to show during settings; the emulator is not running at that point.
///
/// Usage:
/// ```swift
/// TapToRemapView(controller: controller,
///                targetButton: .buttonA) { detected in
///     remapButton(.buttonA, to: detected)
/// } onCancel: {
///     // user dismissed
/// }
/// ```
@MainActor
struct TapToRemapView: View {

    // MARK: Inputs

    let controller: GCController
    /// The logical button that the detected physical button will be mapped *to*.
    let targetButton: ButtonIdentifier
    let onCapture: (ButtonIdentifier) -> Void
    let onCancel: () -> Void

    // MARK: State

    @State private var detectedButton: ButtonIdentifier?
    @State private var isListening = true
    /// The handler that was installed on the gamepad before this view took over.
    /// Restored in `stopListening()` so other app subsystems (remapping, navigation)
    /// continue to function normally after the sheet is dismissed.
    @State private var previousValueChangedHandler: GCExtendedGamepadValueChangedHandler?
    /// Guards against `stopListening()` being called twice (e.g. from the Cancel
    /// button action AND subsequently from `.onDisappear`).  Reset by `startListening()`
    /// so "Try Again" can re-arm the capture flow.
    @State private var hasStopped = false

    // MARK: Body

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            Image(systemName: isListening ? "gamecontroller" : "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(isListening ? .accentColor : .green)

            // Instruction / result
            if isListening {
                Text("Press the controller button you want to assign to **\(targetButton.displayName)**")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if let detected = detectedButton {
                VStack(spacing: 8) {
                    Text("Detected: **\(detected.displayName)**")
                        .font(.title3)
                    Text("Map to \"\(targetButton.displayName)\"?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    Button("Confirm") {
                        onCapture(detected)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Try Again") {
                        detectedButton = nil
                        isListening = true
                        startListening()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top, 4)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                stopListening()
                onCancel()
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 24)
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    // MARK: - Gamepad listener

    private func startListening() {
        guard let gamepad = controller.extendedGamepad else {
            WLOG("TapToRemapView: controller has no extendedGamepad; falling back to cancel")
            onCancel()
            return
        }

        hasStopped = false
        isListening = true
        let wrapper = getRemappableControllerWrapper(for: controller)

        // Save the existing handler so it can be restored when this view is done.
        previousValueChangedHandler = gamepad.valueChangedHandler

        // GCExtendedGamepad.valueChangedHandler fires on a background thread.
        // Capture wrapper weakly to avoid retaining it beyond its useful lifetime.
        // All @MainActor-isolated state mutations (isListening, stopListening, detectedButton)
        // are dispatched to the main actor via Task { @MainActor in }.
        gamepad.valueChangedHandler = { [weak wrapper] _, element in
            // Only respond to button presses (not releases or axis movement).
            guard let button = element as? GCControllerButtonInput, button.isPressed else { return }

            Task { @MainActor in
                // Resolve the identifier on the main actor to keep all wrapper access
                // and @State mutations on the same actor.
                guard let identifier = wrapper?.buttonIdentifier(for: element) else { return }
                // Ignore the menu button — it's reserved for system navigation.
                guard identifier != .menu else { return }
                guard isListening else { return }
                stopListening()
                detectedButton = identifier
                isListening = false
            }
        }
    }

    private func stopListening() {
        // Guard against double-calls (e.g. Cancel button + .onDisappear both firing).
        // Without this, the second call would write nil over the just-restored handler.
        guard !hasStopped else { return }
        hasStopped = true
        // Restore the handler that was active before this view installed its own.
        controller.extendedGamepad?.valueChangedHandler = previousValueChangedHandler
        previousValueChangedHandler = nil
    }
}

