///
/// VirtualInputToggleOverlayView.swift
/// PVUIBase
///
/// A small, unobtrusive SwiftUI overlay that provides quick-toggle buttons for
/// the virtual keyboard and virtual mouse cursor.  Buttons appear only for cores
/// that actually support the respective input type, so the view is completely
/// invisible (zero-size) for cores that need neither.
///
/// Integration
/// -----------
/// Add this view as an overlay inside the default skin / SwiftUI emulator HUD:
///
///     .overlay(alignment: .topLeading) {
///         VirtualInputToggleOverlayView(coreInstance: coreInstance)
///             .padding(.top, safeTopPadding)
///             .padding(.leading, 8)
///     }
///
/// The view communicates with `PVEmulatorViewController` via `NotificationCenter`
/// using the existing `pvToggleVirtualKeyboard` and `pvToggleVirtualMouse` names,
/// so no direct ViewController reference is required.
///
/// Copyright © 2026 Provenance Emu. All rights reserved.
///

#if canImport(UIKit) && !os(tvOS)
import SwiftUI
import PVEmulatorCore
import PVCoreBridge

// MARK: - View Model

/// Observable state that drives the keyboard/mouse toggle button appearance.
@MainActor
final class VirtualInputToggleViewModel: ObservableObject {
    @Published var isKeyboardVisible: Bool = false
    @Published var isMouseVisible: Bool = false

    let supportsKeyboard: Bool
    let supportsMouse: Bool

    init(coreInstance: PVEmulatorCore) {
        supportsKeyboard = (coreInstance as? KeyboardResponder)?.gameSupportsKeyboard == true
        supportsMouse = (coreInstance as? MouseResponder)?.gameSupportsMouse == true
    }

    func toggleKeyboard() {
        NotificationCenter.default.post(name: .pvToggleVirtualKeyboard, object: nil)
        // Optimistically flip local state — the emulator VC corrects it on the next run-loop
        isKeyboardVisible.toggle()
    }

    func toggleMouse() {
        NotificationCenter.default.post(name: .pvToggleVirtualMouse, object: nil)
        isMouseVisible.toggle()
    }
}

// MARK: - Toggle Overlay View

/// A compact HUD strip that shows keyboard and/or mouse toggle buttons when the
/// active core supports those input modes.
public struct VirtualInputToggleOverlayView: View {

    @StateObject private var viewModel: VirtualInputToggleViewModel

    public init(coreInstance: PVEmulatorCore) {
        _viewModel = StateObject(wrappedValue: VirtualInputToggleViewModel(coreInstance: coreInstance))
    }

    public var body: some View {
        HStack(spacing: 8) {
            if viewModel.supportsKeyboard {
                toggleButton(
                    systemImage: "keyboard",
                    accessibilityLabel: "Toggle Virtual Keyboard",
                    isActive: viewModel.isKeyboardVisible,
                    action: { viewModel.toggleKeyboard() }
                )
            }
            if viewModel.supportsMouse {
                toggleButton(
                    systemImage: "cursorarrow",
                    accessibilityLabel: "Toggle Virtual Mouse",
                    isActive: viewModel.isMouseVisible,
                    action: { viewModel.toggleMouse() }
                )
            }
        }
        // Observe keyboard visibility changes posted by the emulator VC
        .onReceive(NotificationCenter.default.publisher(for: .pvShowVirtualKeyboard)) { _ in
            viewModel.isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pvHideVirtualKeyboard)) { _ in
            viewModel.isKeyboardVisible = false
        }
        // Observe mouse visibility changes
        .onReceive(NotificationCenter.default.publisher(for: .pvShowVirtualMouse)) { _ in
            viewModel.isMouseVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pvHideVirtualMouse)) { _ in
            viewModel.isMouseVisible = false
        }
    }

    // MARK: - Private helpers

    @ViewBuilder
    private func toggleButton(
        systemImage: String,
        accessibilityLabel: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .yellow : .white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isActive
                                ? Color.blue.opacity(0.65)
                                : Color.black.opacity(0.45)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isActive ? Color.blue.opacity(0.8) : Color.white.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: isActive ? .blue.opacity(0.5) : .clear, radius: 6, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Preview

#if DEBUG
struct VirtualInputToggleOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.edgesIgnoringSafeArea(.all)
            VStack {
                HStack(spacing: 8) {
                    // Manually simulate the button states for preview
                    previewButton(systemImage: "keyboard", isActive: false)
                    previewButton(systemImage: "keyboard", isActive: true)
                    previewButton(systemImage: "cursorarrow", isActive: false)
                    previewButton(systemImage: "cursorarrow", isActive: true)
                }
                .padding()
            }
        }
        .previewLayout(.sizeThatFits)
    }

    @ViewBuilder
    static func previewButton(systemImage: String, isActive: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isActive ? .yellow : .white)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.blue.opacity(0.65) : Color.black.opacity(0.45))
            )
    }
}
#endif

#endif // canImport(UIKit) && !os(tvOS)
