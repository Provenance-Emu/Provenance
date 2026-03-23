// DOSKeyboardLayout.swift
// PVUI
//
// Companion controller overlay for DOS / DOSBox emulation.
// Wraps the existing VirtualKeyboardView with the full QWERTY layout,
// adding a mouse trackpad area and common DOS shortcut buttons.
//
// Input routing:
//   Keyboard keys → VirtualKeyboardDelegate → CompanionKeyboardBridge
//                 → CompanionInputRouter.sendKeyDown/sendKeyUp
//                 → keyboardMouseEvents publisher → PVEmulatorViewController
//                 → CompanionKeyboardMouseCapable core (PVDosBoxCore.companionKeyDown/Up)
//   Mouse trackpad → DragGesture.onChanged → CompanionInputRouter.sendMouseMove(.mouseMove)
//                  → keyboardMouseEvents publisher → PVEmulatorViewController
//                  → CompanionKeyboardMouseCapable core (PVDosBoxCore.companionMouseMoved)
//   Mouse buttons  → onLongPressGesture → CompanionInputRouter.sendMouseButton(.mouseButton)
//                  → keyboardMouseEvents publisher → PVEmulatorViewController
//                  → CompanionKeyboardMouseCapable core (PVDosBoxCore.companionMouseButton)
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import CoreGraphics
import GameController
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

    /// Bridges VirtualKeyboardDelegate callbacks → CompanionInputRouter keyboard events.
    /// Stored as a @StateObject so it outlives the VirtualKeyboardViewModel's weak delegate ref.
    @StateObject private var keyboardBridge: CompanionKeyboardBridge
    @StateObject private var keyboardVM: VirtualKeyboardViewModel
    @State private var mouseOffset: CGSize = .zero
    @State private var leftButtonDown = false
    @State private var rightButtonDown = false

    // MARK: - Init

    public init(router: CompanionInputRouter) {
        let bridge = CompanionKeyboardBridge(inputRouter: router)
        let vm = VirtualKeyboardViewModel(delegate: bridge, layout: .full, startExpanded: true)
        self._keyboardBridge = StateObject(wrappedValue: bridge)
        self._keyboardVM = StateObject(wrappedValue: vm)
        self.inputRouter = router
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
                            inputRouter.sendMouseButton(0, isDown: true)
                        } onRelease: {
                            leftButtonDown = false
                            inputRouter.sendMouseButton(0, isDown: false)
                        }
                        Spacer()
                        // Right mouse button
                        mouseButton("R", isDown: rightButtonDown) {
                            rightButtonDown = true
                            inputRouter.sendMouseButton(1, isDown: true)
                        } onRelease: {
                            rightButtonDown = false
                            inputRouter.sendMouseButton(1, isDown: false)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        let delta = CGSize(
                            width:  value.translation.width  - mouseOffset.width,
                            height: value.translation.height - mouseOffset.height
                        )
                        mouseOffset = value.translation
                        inputRouter.sendMouseMove(CGPoint(x: delta.width, y: delta.height))
                    }
                    .onEnded { _ in
                        mouseOffset = .zero
                    }
            )
        }
    }

    // MARK: - Quick-access row

    private var quickAccessRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Route through keyboardVM so delegate receives proper GCKeyCode events
                shortcutKey("ESC",   keyCode: .escape)
                shortcutKey("ENTER", keyCode: .returnOrEnter)
                shortcutKey("SPACE", keyCode: .spacebar)
                shortcutKey("TAB",   keyCode: .tab)
                shortcutKey("F1",    keyCode: .F1)
                shortcutKey("F2",    keyCode: .F2)
                shortcutKey("F5",    keyCode: .F5)
                shortcutKey("F10",   keyCode: .F10)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Helpers

    /// Renders a quick-access key that routes through `keyboardVM` so the delegate
    /// receives proper `GCKeyCode` keyDown/keyUp events, matching the path used by
    /// the full QWERTY keys in `VirtualKeyboardView`.
    @ViewBuilder
    private func shortcutKey(_ label: String, keyCode: GCKeyCode) -> some View {
        let key = VirtualKey(label: label, keyCode: keyCode)
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
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 44,
                pressing: { pressing in
                    if pressing {
                        keyboardVM.keyDown(key)
                    } else {
                        keyboardVM.keyUp(key)
                    }
                },
                perform: {}
            )
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
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 44,
                pressing: { pressing in
                    if pressing {
                        if !isDown { onPress() }
                    } else {
                        if isDown { onRelease() }
                    }
                },
                perform: {}
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DOSKeyboardLayout(router: .init())
}
#endif

#endif // !os(tvOS)
