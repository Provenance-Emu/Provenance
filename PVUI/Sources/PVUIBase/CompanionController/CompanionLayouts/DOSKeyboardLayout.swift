// DOSKeyboardLayout.swift
// PVUI
//
// Companion controller overlay for DOS / DOSBox emulation.
// Wraps the existing VirtualKeyboardView with the full QWERTY layout,
// adding a mouse trackpad area and common DOS shortcut buttons.
//
// Input routing:
//   Keyboard keys → VirtualKeyboardDelegate → KeyboardResponder on the DOS core
//   Mouse         → handled by the trackpad gesture (wired in emulator VC)
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVPrimitives

// MARK: - DOSKeyboardLayout

/// System-specific companion overlay for DOS / DOSBox games.
///
/// Shows a full QWERTY keyboard (uses the existing `VirtualKeyboardView`
/// infrastructure), a mouse-trackpad area, and quick-access buttons for
/// common DOS controls (Escape, Enter, Space, function keys).
public struct DOSKeyboardLayout: CompanionLayout {

    // MARK: - CompanionLayout

    public let systemID: String = SystemIdentifier.DOS.rawValue
    public var displayName: String { "DOS / DOSBox" }
    public let inputRouter: CompanionInputRouter

    // MARK: - State

    @StateObject private var keyboardVM: VirtualKeyboardViewModel
    @State private var mouseOffset: CGSize = .zero
    @State private var isMouseDragging = false
    @State private var leftButtonDown = false
    @State private var rightButtonDown = false

    // MARK: - Init

    public init(router: CompanionInputRouter, keyboardDelegate: VirtualKeyboardDelegate? = nil) {
        self.inputRouter = router
        self._keyboardVM = StateObject(wrappedValue: VirtualKeyboardViewModel(delegate: keyboardDelegate, layout: .full, startExpanded: true))
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Mouse trackpad ────────────────────────────────────
                mouseTrackpad
                    .frame(height: 120)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // ── Quick-access row ──────────────────────────────────
                quickAccessRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                // ── Full QWERTY keyboard ──────────────────────────────
                VirtualKeyboardView(viewModel: keyboardVM)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Mouse trackpad

    private var mouseTrackpad: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text("Mouse Trackpad")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))

                    HStack(spacing: 12) {
                        // Left mouse button
                        mouseButton("L", isDown: leftButtonDown) {
                            leftButtonDown = true
                            inputRouter.send(.buttonDown(.south))
                        } onRelease: {
                            leftButtonDown = false
                            inputRouter.send(.buttonUp(.south))
                        }
                        Spacer()
                        // Right mouse button
                        mouseButton("R", isDown: rightButtonDown) {
                            rightButtonDown = true
                            inputRouter.send(.buttonDown(.east))
                        } onRelease: {
                            rightButtonDown = false
                            inputRouter.send(.buttonUp(.east))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        isMouseDragging = true
                        let delta = CGSize(
                            width:  value.translation.width  - mouseOffset.width,
                            height: value.translation.height - mouseOffset.height
                        )
                        mouseOffset = value.translation
                        // Send normalised relative mouse movement via left axis (clamped to -1…1)
                        let scale: CGFloat = 0.01
                        let clampedX = max(-1.0, min(1.0, Float(delta.width  * scale)))
                        let clampedY = max(-1.0, min(1.0, Float(delta.height * scale)))
                        inputRouter.send(.axisChanged(.leftX, clampedX))
                        inputRouter.send(.axisChanged(.leftY, clampedY))
                    }
                    .onEnded { _ in
                        isMouseDragging = false
                        mouseOffset     = .zero
                        inputRouter.send(.axisChanged(.leftX, 0))
                        inputRouter.send(.axisChanged(.leftY, 0))
                    }
            )
        }
    }

    // MARK: - Quick-access row

    private var quickAccessRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                shortcutButton("ESC",   button: .select)
                shortcutButton("ENTER", button: .start)
                // Use .west/.north to avoid collision with mouse L (.south) and mouse R (.east)
                shortcutButton("SPACE", button: .west)
                shortcutButton("TAB",   button: .north)
                shortcutButton("F1",    button: .l1)
                shortcutButton("F2",    button: .r1)
                shortcutButton("F5",    button: .l2)
                shortcutButton("F10",   button: .r2)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func shortcutButton(_ label: String, button: CompanionButton) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .frame(height: 32)
                .overlay(
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                )
        }
    }

    @ViewBuilder
    private func mouseButton(
        _ label: String,
        isDown: Bool,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isDown ? Color.white.opacity(0.3) : Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .frame(width: 60, height: 28)
            .overlay(
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDown { onPress() }
                    }
                    .onEnded { _ in
                        if isDown { onRelease() }
                    }
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DOSKeyboardLayout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
