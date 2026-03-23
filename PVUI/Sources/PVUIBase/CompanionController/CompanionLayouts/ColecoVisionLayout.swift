// ColecoVisionLayout.swift
// PVUI
//
// Companion controller overlay for the ColecoVision.
// Displays the 12-key numeric keypad, 2 side action buttons, and a joystick.
//
// Input routing:
//   Numpad (0-9, *, #) → CompanionButton.num0/.num1.../.numStar/.numHash
//   Left action button → CompanionButton.south
//   Right action button → CompanionButton.east
//   D-pad              → CompanionButton.dpadUp/.dpadDown/.dpadLeft/.dpadRight
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVCoreBridge
import PVPrimitives

// MARK: - ColecoVisionLayout

/// System-specific companion overlay for the ColecoVision.
///
/// Layout (landscape):
/// ```
///  [LEFT BTN]  [ Numpad 1–9, *, 0, # ]  [RIGHT BTN]
///
///           [ D-pad / Joystick ]
/// ```
public struct ColecoVisionLayout: CompanionLayout {

    // MARK: - CompanionLayout

    public let systemID: String = SystemIdentifier.ColecoVision.rawValue
    public var displayName: String { "ColecoVision" }
    public let inputRouter: CompanionInputRouter

    // MARK: - Init

    public init(router: CompanionInputRouter) {
        self.inputRouter = router
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // ── Main row: action buttons flanking the numpad ───────
                HStack(alignment: .center, spacing: 24) {
                    // Left action button
                    actionButton("L", button: .south, color: .yellow)

                    // 12-key numpad (3 keys per row)
                    NumpadLayout(
                        keys: StandardNumpadKeys.phoneLayout,
                        router: inputRouter,
                        keysPerRow: 3,
                        keySize: 56,
                        keySpacing: 6
                    )

                    // Right action button
                    actionButton("R", button: .east, color: .yellow)
                }
                .padding(.horizontal, 20)

                Spacer()

                // ── D-pad ─────────────────────────────────────────────
                CompanionControllerDpad(router: inputRouter)
                    .frame(width: 110, height: 110)
                    .padding(.bottom, 12)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func actionButton(_ label: String, button: CompanionButton, color: Color) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 52, height: 80)
                .overlay(
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ColecoVisionLayout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
