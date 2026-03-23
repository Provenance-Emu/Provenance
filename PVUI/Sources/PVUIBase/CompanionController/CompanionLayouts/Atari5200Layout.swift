// Atari5200Layout.swift
// PVUI
//
// Companion controller overlay for the Atari 5200 Super System.
// Displays the 12-key numeric keypad, 2 fire buttons, Start/Pause/Reset
// side buttons, and an analog joystick.
//
// Input routing:
//   Numpad (0-9, *, #) → CompanionButton.num0/.num1.../.numStar/.numHash
//   Fire 1 / Fire 2    → CompanionButton.south / .east
//   Start              → CompanionButton.start
//   Pause              → CompanionButton.select
//   Reset              → CompanionButton.l1  (mapped by companion wiring layer)
//   Analog joystick    → CompanionAxisID.leftX / .leftY
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVCoreBridge
import PVPrimitives

// MARK: - Atari5200Layout

/// System-specific companion overlay for the Atari 5200.
///
/// Layout (landscape):
/// ```
/// [ START ] [ PAUSE ] [ RESET ]     (top-left side buttons)
///
///     [ Numpad 1–9, *, 0, # ]       (centre)
///
///      [  Analog Joystick  ]         (bottom-left)
///  [ FIRE 1 ]           [ FIRE 2 ]  (bottom sides)
/// ```
public struct Atari5200Layout: CompanionLayout {

    // MARK: - CompanionLayout

    public let systemID: String = SystemIdentifier.Atari5200.rawValue
    public var displayName: String { "Atari 5200" }
    public let inputRouter: CompanionInputRouter

    // MARK: - Init

    public init(router: CompanionInputRouter) {
        self.inputRouter = router
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                // ── Top: side-panel buttons ──────────────────────────
                HStack(spacing: 12) {
                    sideButton("START", button: .start, color: .green)
                    sideButton("PAUSE", button: .select, color: .yellow)
                    sideButton("RESET", button: .l1, color: .red)
                    Spacer()
                }
                .padding(.horizontal, 20)

                Spacer()

                // ── Middle: numpad + joystick ─────────────────────────
                HStack(alignment: .center, spacing: 32) {
                    // Analog joystick
                    CompanionControllerAxis(
                        axisX: .leftX, axisY: .leftY,
                        router: inputRouter,
                        maxRadius: 44
                    )
                    .frame(width: 110, height: 110)

                    // 12-key numeric pad
                    NumpadLayout(
                        keys: StandardNumpadKeys.phoneLayout,
                        router: inputRouter,
                        keysPerRow: 3,
                        keySize: 54,
                        keySpacing: 6
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                // ── Bottom: fire buttons ─────────────────────────────
                HStack {
                    fireButton("FIRE 1", button: .south, color: .orange)
                    Spacer()
                    fireButton("FIRE 2", button: .east, color: .orange)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sideButton(_ label: String, button: CompanionButton, color: Color) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 72, height: 36)
                .overlay(
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                )
        }
    }

    @ViewBuilder
    private func fireButton(_ label: String, button: CompanionButton, color: Color) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 90, height: 52)
                .overlay(
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Atari5200Layout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
