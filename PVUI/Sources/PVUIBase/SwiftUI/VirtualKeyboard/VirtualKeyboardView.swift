// VirtualKeyboardView.swift
// PVUI
//
// SwiftUI virtual keyboard overlay for on-screen key input during emulation.
// Supports platform-specific layouts (C64, ZX Spectrum, Amstrad CPC, etc.)
// and fires GCKeyCode events consumed by the emulator core.
//
// Copyright © 2024 Provenance Emu. All rights reserved.

import SwiftUI
import GameController

// MARK: - VirtualKeyboardDelegate

/// Receives key press and release events from the virtual keyboard overlay.
public protocol VirtualKeyboardDelegate: AnyObject {
    func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyDown key: VirtualKey)
    func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyUp key: VirtualKey)
}

// MARK: - VirtualKeyboardViewModel

/// Observable state for the virtual keyboard overlay.
@MainActor
public final class VirtualKeyboardViewModel: ObservableObject {
    /// The currently selected layout.
    @Published public var layout: VirtualKeyboardLayout
    /// Set of currently active (pressed) modifier key IDs.
    @Published public var activeModifiers: Set<GCKeyCode> = []
    /// Overall opacity of the keyboard overlay (0.0–1.0).
    @Published public var opacity: Double = 0.85

    public init(layout: VirtualKeyboardLayout = .full) {
        self.layout = layout
    }

    /// Toggles a sticky modifier key on/off.
    public func toggleModifier(_ keyCode: GCKeyCode) {
        if activeModifiers.contains(keyCode) {
            activeModifiers.remove(keyCode)
        } else {
            activeModifiers.insert(keyCode)
        }
    }

    /// Returns `true` if the given modifier key is currently active.
    public func isModifierActive(_ keyCode: GCKeyCode) -> Bool {
        activeModifiers.contains(keyCode)
    }
}

// MARK: - VirtualKeyboardView

/// Overlay virtual keyboard for iOS/tvOS emulator screens.
///
/// Usage:
/// ```swift
/// VirtualKeyboardView(viewModel: keyboardViewModel, delegate: self)
/// ```
///
/// The view renders the rows defined by `viewModel.layout.rows` and
/// calls `delegate.virtualKeyboard(_:keyDown:)` / `keyUp:` for each touch.
/// Sticky modifiers remain highlighted until tapped again.
public struct VirtualKeyboardView: View {
    @ObservedObject public var viewModel: VirtualKeyboardViewModel
    public weak var delegate: VirtualKeyboardDelegate?

    public init(viewModel: VirtualKeyboardViewModel, delegate: VirtualKeyboardDelegate? = nil) {
        self.viewModel = viewModel
        self.delegate = delegate
    }

    public var body: some View {
        VStack(spacing: 0) {
            layoutPickerToolbar
            keyboardRows
        }
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(viewModel.opacity)
    }

    // MARK: Layout Picker Toolbar

    private var layoutPickerToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(VirtualKeyboardLayout.allCases) { layoutCase in
                    Button(action: {
                        viewModel.layout = layoutCase
                        viewModel.activeModifiers.removeAll()
                    }) {
                        Text(layoutCase.displayName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.layout == layoutCase
                                        ? Color.accentColor
                                        : Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color.white.opacity(0.05))
    }

    // MARK: Key Rows

    private var keyboardRows: some View {
        VStack(spacing: 3) {
            ForEach(viewModel.layout.rows.indices, id: \.self) { rowIndex in
                keyRow(viewModel.layout.rows[rowIndex])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private func keyRow(_ keys: [VirtualKey]) -> some View {
        HStack(spacing: 3) {
            ForEach(keys) { key in
                VirtualKeyButton(
                    key: key,
                    isActive: viewModel.isModifierActive(key.keyCode),
                    onPress: { handleKeyPress(key) },
                    onRelease: { handleKeyRelease(key) }
                )
            }
        }
    }

    // MARK: Event Handling

    private func handleKeyPress(_ key: VirtualKey) {
        if key.isModifier {
            viewModel.toggleModifier(key.keyCode)
            if viewModel.isModifierActive(key.keyCode) {
                delegate?.virtualKeyboard(self, keyDown: key)
            } else {
                delegate?.virtualKeyboard(self, keyUp: key)
            }
        } else {
            delegate?.virtualKeyboard(self, keyDown: key)
        }
    }

    private func handleKeyRelease(_ key: VirtualKey) {
        guard !key.isModifier else { return }
        delegate?.virtualKeyboard(self, keyUp: key)
    }
}

// MARK: - VirtualKeyButton

/// A single key button in the virtual keyboard overlay.
private struct VirtualKeyButton: View {
    let key: VirtualKey
    let isActive: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    private static let baseKeyHeight: CGFloat = 36
    private static let baseKeyWidth: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)

            keyLabel
        }
        .frame(width: Self.baseKeyWidth * key.widthMultiplier, height: Self.baseKeyHeight)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
    }

    @ViewBuilder
    private var keyLabel: some View {
        if let symbolName = key.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(labelColor)
                .allowsTightening(true)
        } else {
            Text(key.label)
                .font(.system(size: labelFontSize, weight: labelWeight, design: .monospaced))
                .foregroundColor(labelColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
        }
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.85)
        }
        if isPressed {
            return Color.white.opacity(0.35)
        }
        if key.isModifier {
            return Color.gray.opacity(0.45)
        }
        return Color.white.opacity(0.18)
    }

    private var labelColor: Color {
        isActive ? .white : .white.opacity(0.9)
    }

    private var labelFontSize: CGFloat {
        let len = key.label.count
        if len <= 1 { return 14 }
        if len <= 3 { return 11 }
        return 9
    }

    private var labelWeight: Font.Weight {
        key.isModifier ? .semibold : .regular
    }
}

// MARK: - VirtualKeyboardOverlayModifier

/// View modifier that attaches the virtual keyboard overlay to an emulator view.
///
/// Example:
/// ```swift
/// EmulatorMetalView()
///     .virtualKeyboardOverlay(viewModel: keyboardVM, delegate: self)
/// ```
public struct VirtualKeyboardOverlayModifier: ViewModifier {
    @ObservedObject var viewModel: VirtualKeyboardViewModel
    weak var delegate: VirtualKeyboardDelegate?

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomLeading) {
                if !viewModel.activeModifiers.isEmpty || true {
                    VirtualKeyboardView(viewModel: viewModel, delegate: delegate)
                        .frame(maxWidth: 420)
                        .padding(.bottom, 8)
                        .padding(.leading, 8)
                }
            }
    }
}

public extension View {
    /// Attaches a floating virtual keyboard overlay to this view.
    func virtualKeyboardOverlay(
        viewModel: VirtualKeyboardViewModel,
        delegate: VirtualKeyboardDelegate? = nil
    ) -> some View {
        modifier(VirtualKeyboardOverlayModifier(viewModel: viewModel, delegate: delegate))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("C64 Layout") {
    let vm = VirtualKeyboardViewModel(layout: .c64)
    return VirtualKeyboardView(viewModel: vm)
        .padding()
        .background(Color.gray)
}

#Preview("ZX Spectrum Layout") {
    let vm = VirtualKeyboardViewModel(layout: .zxSpectrum)
    return VirtualKeyboardView(viewModel: vm)
        .padding()
        .background(Color.gray)
}

#Preview("Amstrad CPC Layout") {
    let vm = VirtualKeyboardViewModel(layout: .amstradCPC)
    return VirtualKeyboardView(viewModel: vm)
        .padding()
        .background(Color.gray)
}
#endif
