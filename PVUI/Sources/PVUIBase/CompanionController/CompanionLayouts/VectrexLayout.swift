// VectrexLayout.swift
// PVUI
//
// Companion controller overlay for the Vectrex.
// Displays the analog joystick and four action buttons.
// The Vectrex used a rotary joystick controller with 4 side buttons.
//
// Input routing:
//   Analog joystick → CompanionAxisID.leftX / .leftY
//   Button 1–4      → CompanionButton.south / .east / .west / .north
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVCoreBridge
import PVPrimitives

// MARK: - VectrexLayout

/// System-specific companion overlay for the Vectrex.
///
/// Layout (landscape):
/// ```
///   [ Analog Joystick ]    [ 1 ]  [ 2 ]
///                          [ 3 ]  [ 4 ]
/// ```
///
/// Buttons are labelled 1–4, matching the physical Vectrex controller.
/// Colours match the traditional Vectrex button colours.
public struct VectrexLayout: CompanionLayout {

    // MARK: - CompanionLayout

    public let systemID: String = SystemIdentifier.Vectrex.rawValue
    public var displayName: String { "Vectrex" }
    public let inputRouter: CompanionInputRouter

    // MARK: - Init

    public init(router: CompanionInputRouter) {
        self.inputRouter = router
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(alignment: .center, spacing: 48) {
                // Left: analog joystick
                VStack {
                    Spacer()
                    CompanionControllerAxis(
                        axisX: .leftX, axisY: .leftY,
                        router: inputRouter,
                        maxRadius: 48,
                        thumbColor: .white,
                        baseColor: Color.white.opacity(0.12)
                    )
                    .frame(width: 130, height: 130)
                    Spacer()
                }

                // Right: 2×2 button grid (Vectrex buttons 1–4)
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        vectrexButton("1", button: .south, color: .blue)
                        vectrexButton("2", button: .east,  color: .yellow)
                    }
                    HStack(spacing: 14) {
                        vectrexButton("3", button: .west,  color: .red)
                        vectrexButton("4", button: .north, color: .green)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func vectrexButton(_ label: String, button: CompanionButton, color: Color) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            Circle()
                .fill(color.opacity(0.30))
                .overlay(Circle().stroke(color.opacity(0.7), lineWidth: 2))
                .frame(width: 70, height: 70)
                .overlay(
                    Text(label)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VectrexLayout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
