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
///         VirtualInputToggleOverlayView()
///             .padding(.top, safeTopPadding)
///             .padding(.leading, 8)
///     }
///
/// State is driven by a `VirtualInputState` environment object owned by
/// `PVEmulatorViewController` and injected via `.environmentObject(_:)`.
/// No `NotificationCenter` coupling is required.
///
/// Copyright © 2026 Provenance Emu. All rights reserved.
///

#if canImport(UIKit) && !os(tvOS)
import SwiftUI

// MARK: - Toggle Overlay View

/// A compact HUD strip that shows keyboard and/or mouse toggle buttons when the
/// active core supports those input modes.
///
/// State is provided by `VirtualInputState` via the SwiftUI environment, ensuring
/// the buttons always reflect the true overlay visibility regardless of which code
/// path triggered the change (user tap, hardware keyboard connect, pause menu, etc.).
public struct VirtualInputToggleOverlayView: View {

    @EnvironmentObject private var state: VirtualInputState

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            if state.supportsKeyboard {
                toggleButton(
                    systemImage: "keyboard",
                    accessibilityLabel: "Toggle Virtual Keyboard",
                    isActive: state.isKeyboardVisible,
                    action: { state.onToggleKeyboard() }
                )
            }
            if state.supportsMouse {
                toggleButton(
                    systemImage: "cursorarrow",
                    accessibilityLabel: "Toggle Virtual Mouse",
                    isActive: state.isMouseVisible,
                    action: { state.onToggleMouse() }
                )
            }
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
