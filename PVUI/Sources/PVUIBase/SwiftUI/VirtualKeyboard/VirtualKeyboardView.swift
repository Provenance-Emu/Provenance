// VirtualKeyboardView.swift
// PVUI
//
// SwiftUI virtual keyboard overlay for on-screen key input during emulation.
// Supports platform-specific layouts (C64, ZX Spectrum, Amstrad CPC, etc.)
// with haptic feedback and a swipe-down dismiss gesture.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import UIKit
import GameController

// MARK: - VirtualKeyboardView

/// Bottom-sheet keyboard overlay rendered as a SwiftUI view hosted via UIHostingController.
///
/// The view model (`VirtualKeyboardViewModel`) owns all state — modifier tracking,
/// key event forwarding via `VirtualKeyboardDelegate`, and the dismiss callback.
public struct VirtualKeyboardView: View {

    @ObservedObject var viewModel: VirtualKeyboardViewModel

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var isLandscape: Bool {
        hSizeClass == .regular && vSizeClass == .compact
    }

    public init(viewModel: VirtualKeyboardViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                keyboardSheet(in: geometry)
            }
            .ignoresSafeArea(.keyboard)
        }
        .gesture(swipeDownDismiss)
    }

    // MARK: - Sheet

    private func keyboardSheet(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handleBar
            closeButtonRow
            layoutPickerToolbar
            keyboardContent(in: geometry)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 4)
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 4)
    }

    // MARK: - Handle bar

    private var handleBar: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: - Close button

    private var closeButtonRow: some View {
        HStack {
            Spacer()
            Button(action: {
                haptic.impactOccurred()
                viewModel.dismissAction?()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 20))
                    .padding(8)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Layout picker toolbar

    private var layoutPickerToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(VirtualKeyboardLayout.allCases) { layoutCase in
                    Button(action: {
                        viewModel.selectLayout(layoutCase)
                    }) {
                        Text(layoutCase.displayName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.layout == layoutCase
                                    ? Color.accentColor
                                    : Color.white.opacity(0.15)
                            )
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

    // MARK: - Key rows

    @ViewBuilder
    private func keyboardContent(in geometry: GeometryProxy) -> some View {
        let rows = viewModel.layout.rows
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                keyRow(rows[rowIndex], availableWidth: geometry.size.width - 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func keyRow(_ keys: [VirtualKey], availableWidth: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(keys) { key in
                VirtualKeyButton(key: key, viewModel: viewModel)
                    .frame(width: keyWidth(for: key, in: keys, availableWidth: availableWidth))
            }
        }
    }

    private func keyWidth(for key: VirtualKey, in row: [VirtualKey], availableWidth: CGFloat) -> CGFloat {
        let totalFactors = row.reduce(0.0) { $0 + $1.widthMultiplier }
        let spacing = CGFloat(row.count - 1) * 3
        let usable = availableWidth - spacing
        return max(24, (usable / totalFactors) * key.widthMultiplier)
    }

    // MARK: - Dismiss gesture

    private var swipeDownDismiss: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.height > 40 {
                    haptic.impactOccurred()
                    viewModel.dismissAction?()
                }
            }
    }
}

// MARK: - VirtualKeyButton

private struct VirtualKeyButton: View {

    let key: VirtualKey
    @ObservedObject var viewModel: VirtualKeyboardViewModel

    @State private var isPressed: Bool = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var isModifierActive: Bool {
        if key.keyCode == .capsLock { return viewModel.capsLockOn }
        return viewModel.activeModifiers.contains(key.keyCode)
    }

    var body: some View {
        ZStack {
            keyBackground
            keyLabel
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        haptic.impactOccurred()
                        viewModel.keyDown(key)
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        isPressed = false
                        viewModel.keyUp(key)
                    }
                }
        )
        .accessibilityLabel(key.label)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var keyLabel: some View {
        if let symbolName = key.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(labelColor)
        } else {
            Text(key.label)
                .font(labelFont)
                .foregroundColor(labelColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
        }
    }

    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
    }

    private var backgroundColor: Color {
        if isPressed { return Color.white.opacity(0.35) }
        if isModifierActive { return Color.blue.opacity(0.55) }
        if key.isModifier { return Color.white.opacity(0.18) }
        return Color.white.opacity(0.14)
    }

    private var strokeColor: Color {
        if isModifierActive { return Color.blue.opacity(0.8) }
        return Color.white.opacity(0.25)
    }

    private var labelColor: Color {
        if isModifierActive { return .white }
        return Color.white.opacity(0.88)
    }

    private var labelFont: Font {
        let len = key.label.count
        if len <= 1 { return .system(size: 13, weight: .regular) }
        if len <= 3 { return .system(size: 11, weight: .medium) }
        return .system(size: 9, weight: .medium)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Full Layout") {
    ZStack {
        Color.gray.ignoresSafeArea()
        VirtualKeyboardView(viewModel: VirtualKeyboardViewModel())
    }
    .preferredColorScheme(.dark)
}

#Preview("C64 Layout") {
    let vm = VirtualKeyboardViewModel()
    vm.layout = .c64
    return ZStack {
        Color.gray.ignoresSafeArea()
        VirtualKeyboardView(viewModel: vm)
    }
    .preferredColorScheme(.dark)
}
#endif
#endif // !os(tvOS)
