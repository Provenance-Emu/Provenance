// VirtualKeyboardView.swift
// PVUI
//
// SwiftUI virtual keyboard overlay for on-screen key input during emulation.
// iOS: Supports platform-specific layouts (C64, ZX Spectrum, Amstrad CPC, etc.)
//      with haptic feedback and a swipe-down dismiss gesture.
// tvOS: A lightweight QWERTY keyboard navigable with the Siri Remote D-pad.
//       Only shown for cores that report `requiresKeyboard == true`.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import SwiftUI
import GameController

#if os(tvOS)

// MARK: - ViewModel (tvOS)

/// tvOS keyboard view model using shared VirtualKeyboardLayout for D-pad navigation.
@MainActor
public final class VirtualKeyboardViewModel: ObservableObject {
    @Published public var selectedRow: Int = 0
    @Published public var selectedColumn: Int = 0
    @Published public var isVisible: Bool = false
    @Published public var layout: VirtualKeyboardLayout = .full

    private var rows: [[VirtualKey]] { layout.rows }

    public var currentKey: VirtualKey? {
        guard selectedRow < rows.count, selectedColumn < rows[selectedRow].count else { return nil }
        return rows[selectedRow][selectedColumn]
    }

    public init(layout: VirtualKeyboardLayout = .full) {
        self.layout = layout
    }

    public func moveUp() {
        if selectedRow > 0 {
            selectedRow -= 1
            selectedColumn = min(selectedColumn, rows[selectedRow].count - 1)
        }
    }

    public func moveDown() {
        if selectedRow < rows.count - 1 {
            selectedRow += 1
            selectedColumn = min(selectedColumn, rows[selectedRow].count - 1)
        }
    }

    public func moveLeft() {
        if selectedColumn > 0 {
            selectedColumn -= 1
        }
    }

    public func moveRight() {
        if selectedColumn < rows[selectedRow].count - 1 {
            selectedColumn += 1
        }
    }

    public func rows(at index: Int) -> [VirtualKey] {
        guard index < rows.count else { return [] }
        return rows[index]
    }

    public var rowCount: Int { rows.count }
}

// MARK: - View (tvOS)

/// A D-pad navigable on-screen keyboard for tvOS.
/// Embed this in the emulator UI and pass a `VirtualKeyboardViewModel` plus a
/// callback that receives the selected `GCKeyCode`.
public struct VirtualKeyboardView: View {
    @ObservedObject var viewModel: VirtualKeyboardViewModel
    /// Called with the key code when the user confirms a key (buttonA / Select).
    public var onKeyPress: (GCKeyCode) -> Void
    /// Called with the key code when the user releases a key.
    public var onKeyRelease: (GCKeyCode) -> Void

    private let keySize: CGFloat = 56
    private let keySpacing: CGFloat = 8

    public init(
        viewModel: VirtualKeyboardViewModel,
        onKeyPress: @escaping (GCKeyCode) -> Void,
        onKeyRelease: @escaping (GCKeyCode) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onKeyPress = onKeyPress
        self.onKeyRelease = onKeyRelease
    }

    public var body: some View {
        VStack(spacing: keySpacing) {
            ForEach(0 ..< viewModel.rowCount, id: \.self) { rowIndex in
                HStack(spacing: keySpacing) {
                    ForEach(viewModel.rows(at: rowIndex)) { key in
                        KeyCell(
                            key: key,
                            isSelected: viewModel.selectedRow == rowIndex
                                && viewModel.selectedColumn == viewModel.rows(at: rowIndex).firstIndex(of: key),
                            keySize: keySize
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
        )
        // D-pad navigation via focusable + onMoveCommand is not available on tvOS 14,
        // so we use a UIKit-backed approach via the hosting controller's pressesBegan.
        // The VirtualKeyboardHostingController exposes navigation methods on the viewModel.
    }
}

// MARK: - KeyCell (tvOS)

private struct KeyCell: View {
    let key: VirtualKey
    let isSelected: Bool
    let keySize: CGFloat

    var body: some View {
        Text(key.label)
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .foregroundColor(isSelected ? .black : .white)
            .frame(
                width: keySize * key.widthMultiplier + (key.widthMultiplier > 1 ? 8 * (key.widthMultiplier - 1) : 0),
                height: keySize
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.yellow : Color.white.opacity(0.15))
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isSelected)
    }
}

// MARK: - UIKit hosting controller (tvOS)

/// A UIKit hosting controller that intercepts press events (Siri Remote / game
/// controller D-pad) to drive `VirtualKeyboardViewModel` navigation.
public final class VirtualKeyboardHostingController: UIHostingController<VirtualKeyboardView> {
    private let viewModel: VirtualKeyboardViewModel
    public var onKeyPress: (GCKeyCode) -> Void = { _ in }
    public var onKeyRelease: (GCKeyCode) -> Void = { _ in }

    public init(viewModel: VirtualKeyboardViewModel) {
        self.viewModel = viewModel
        let rootView = VirtualKeyboardView(
            viewModel: viewModel,
            onKeyPress: { _ in },
            onKeyRelease: { _ in }
        )
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var canBecomeFirstResponder: Bool { true }

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.type {
            case .upArrow:    viewModel.moveUp()
            case .downArrow:  viewModel.moveDown()
            case .leftArrow:  viewModel.moveLeft()
            case .rightArrow: viewModel.moveRight()
            case .select:
                if let key = viewModel.currentKey {
                    onKeyPress(key.keyCode)
                }
            default:
                super.pressesBegan([press], with: event)
            }
        }
    }

    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .select, let key = viewModel.currentKey {
                onKeyRelease(key.keyCode)
            } else {
                super.pressesEnded([press], with: event)
            }
        }
    }
}

#else // !os(tvOS) - iOS / iPadOS

import UIKit

// MARK: - VirtualKeyboardView (iOS)

/// Bottom-sheet keyboard overlay rendered as a SwiftUI view hosted via UIHostingController.
///
/// The view model (`VirtualKeyboardViewModel`) owns all state - modifier tracking,
/// key event forwarding via `VirtualKeyboardDelegate`, and the dismiss callback.
public struct VirtualKeyboardView: View {

    @ObservedObject var viewModel: VirtualKeyboardViewModel

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    /// Live drag translation while the user is repositioning the sheet.
    @GestureState private var dragTranslation: CGFloat = 0

    private static let dragCoordinateSpace = "VirtualKeyboardContainer"

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
            // Reposition via bottom padding (a real layout change) rather than
            // `.offset`, so the reported sheet frame matches its visual position
            // and hit-testing stays accurate. `verticalOffset` is non-positive
            // (negative == lift); negating it yields upward bottom padding.
            .padding(.bottom, max(0, -(viewModel.verticalOffset + dragTranslation)))
            .ignoresSafeArea(.keyboard)
            .coordinateSpace(name: Self.dragCoordinateSpace)
            // Report the visible sheet's frame (already includes the offset) so the
            // passthrough container can gate hit-testing to just the visible area.
            .onPreferenceChange(KeyboardFramePreferenceKey.self) { frame in
                viewModel.keyboardFrame = frame
            }
        }
    }

    // MARK: - Sheet

    private func keyboardSheet(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            collapseHandleBar(in: geometry)
            if !viewModel.isCollapsed {
                closeButtonRow
                layoutPickerToolbar
                keyboardContent(in: geometry)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
        // Publish the visible sheet's frame (in the container coordinate space) so
        // the passthrough container can pass through touches outside of it.
        .background(
            GeometryReader { sheetGeo in
                Color.clear.preference(
                    key: KeyboardFramePreferenceKey.self,
                    value: sheetGeo.frame(in: .named(Self.dragCoordinateSpace))
                )
            }
        )
        .padding(.horizontal, 4)
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 4)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isCollapsed)
    }

    // MARK: - Collapse handle bar
    //
    // Tapping the handle (or the "−" chevron) toggles collapsed ↔ expanded.
    // Dragging the handle vertically repositions the whole sheet.
    // A dedicated X button in the toolbar is the only way to fully dismiss.

    private func collapseHandleBar(in geometry: GeometryProxy) -> some View {
        Button(action: {
            haptic.impactOccurred()
            viewModel.isCollapsed.toggle()
        }) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 4)
                Image(systemName: viewModel.isCollapsed ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 6)
            .padding(.bottom, viewModel.isCollapsed ? 6 : 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Drag the handle vertically to reposition the sheet; a fast downward
        // flick while expanded collapses it. Scoped to the handle (not the full
        // view) so key presses are never intercepted.
        .simultaneousGesture(repositionDrag(in: geometry))
    }

    // MARK: - Close button (dismiss entirely)

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

    // MARK: - Reposition drag (vertical) + swipe-down collapse

    /// A vertical drag on the handle bar that repositions the sheet live and,
    /// on a fast downward flick while expanded, collapses it instead.
    /// Never dismisses the keyboard.
    private func repositionDrag(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let height = value.translation.height
                // A clear downward flick while expanded collapses the sheet
                // (preserves the previous swipe-down-to-collapse behaviour).
                if !viewModel.isCollapsed, height > 60 {
                    haptic.impactOccurred()
                    viewModel.isCollapsed = true
                    return
                }
                // Otherwise commit the new position, clamped on-screen.
                let proposed = viewModel.verticalOffset + height
                viewModel.verticalOffset = VirtualKeyboardViewModel.clampVerticalOffset(
                    proposed,
                    sheetHeight: viewModel.keyboardFrame.height,
                    containerHeight: geometry.size.height,
                    topInset: geometry.safeAreaInsets.top
                )
            }
    }
}

// MARK: - Keyboard frame preference key (iOS)

/// Propagates the visible keyboard sheet's frame up to the container view so
/// the passthrough container can gate hit-testing to the visible area only.
struct KeyboardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - VirtualKeyButton (iOS)

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

// MARK: - Preview (iOS)

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

#Preview("Compact Layout") {
    let vm = VirtualKeyboardViewModel()
    vm.layout = .compact
    return ZStack {
        Color.gray.ignoresSafeArea()
        VirtualKeyboardView(viewModel: vm)
    }
    .preferredColorScheme(.dark)
}

#Preview("Function Row") {
    let vm = VirtualKeyboardViewModel()
    vm.layout = .functionRow
    return ZStack {
        Color.gray.ignoresSafeArea()
        VirtualKeyboardView(viewModel: vm)
    }
    .preferredColorScheme(.dark)
}
#endif

#endif // os(tvOS)
