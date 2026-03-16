// GenericCompanionLayout.swift
// PVUI
//
// A fallback CompanionLayout used when no system-specific layout has been
// registered for the active system identifier.  Also serves as a TestLayout
// for validating end-to-end event routing during development.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI

// MARK: - GenericCompanionLayout

/// A minimal companion layout with a D-pad, two analogue sticks, four face
/// buttons, shoulder buttons and Start/Select.  Works with any system and
/// confirms that `CompanionInputRouter` routing is operational.
public struct GenericCompanionLayout: CompanionLayout {

    // MARK: - CompanionLayout conformance

    public let systemID: String
    public var displayName: String { "Generic Controller" }
    public let inputRouter: CompanionInputRouter

    // MARK: - Init

    public init(systemID: String = "", router: CompanionInputRouter) {
        self.systemID    = systemID
        self.inputRouter = router
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Shoulder row
                HStack {
                    shoulderButton("L1", button: .l1)
                    Spacer()
                    shoulderButton("R1", button: .r1)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Main row: D-pad | face buttons
                HStack(alignment: .center, spacing: 40) {
                    // Left side: D-pad + left stick
                    VStack(spacing: 16) {
                        CompanionControllerDpad(router: inputRouter)
                            .frame(width: 110, height: 110)
                        CompanionControllerAxis(
                            axisX: .leftX, axisY: .leftY,
                            router: inputRouter
                        )
                        .frame(width: 80, height: 80)
                    }

                    // Centre: Select / Start
                    VStack(spacing: 12) {
                        faceButton("SEL", button: .select, color: .gray)
                        faceButton("STA", button: .start, color: .gray)
                    }

                    // Right side: face buttons + right stick
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            VStack(spacing: 8) {
                                faceButton("Y", button: .north,  color: .yellow)
                                HStack(spacing: 8) {
                                    faceButton("X", button: .west,  color: .blue)
                                    faceButton("A", button: .south, color: .green)
                                }
                                faceButton("B", button: .east,  color: .red)
                            }
                        }
                        CompanionControllerAxis(
                            axisX: .rightX, axisY: .rightY,
                            router: inputRouter
                        )
                        .frame(width: 80, height: 80)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Helper builders

    @ViewBuilder
    private func faceButton(_ label: String, button: CompanionButton, color: Color) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    @ViewBuilder
    private func shoulderButton(_ label: String, button: CompanionButton) -> some View {
        CompanionControllerButton(button: button, router: inputRouter) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.15))
                .frame(width: 64, height: 32)
                .overlay(
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    GenericCompanionLayout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
