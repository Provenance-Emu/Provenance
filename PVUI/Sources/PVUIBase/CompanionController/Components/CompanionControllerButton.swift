// CompanionControllerButton.swift
// PVUI
//
// Reusable touch-target button for companion controller overlays.
// Sends button-down/up events through the CompanionInputRouter on press/release.
// Supports haptic feedback and custom styling per system.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import SwiftUI

// MARK: - CompanionControllerButton

/// A single pressable button in a companion layout overlay.
///
/// Wrap this in a `CompanionLayout` body to build up system-specific overlays:
/// ```swift
/// CompanionControllerButton(button: .south, router: inputRouter) {
///     Circle().fill(Color.blue).overlay(Text("A").foregroundColor(.white))
/// }
/// ```
public struct CompanionControllerButton<Label: View>: View {

    // MARK: - Properties

    private let button: CompanionButton
    private let router: CompanionInputRouter
    private let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    private let label: Label

    // MARK: - State

    @State private var isPressed: Bool = false

    // MARK: - Init

    public init(
        button: CompanionButton,
        router: CompanionInputRouter,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        @ViewBuilder label: () -> Label
    ) {
        self.button      = button
        self.router      = router
        self.hapticStyle = hapticStyle
        self.label       = label()
    }

    // MARK: - Body

    public var body: some View {
        label
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            triggerHaptic()
                            router.send(.buttonDown(button))
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            router.send(.buttonUp(button))
                        }
                    }
            )
    }

    // MARK: - Haptics

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: hapticStyle)
        generator.impactOccurred()
    }
}

// MARK: - Convenience initialisers

extension CompanionControllerButton where Label == Text {
    /// Create a text-labelled button.
    public init(
        _ title: String,
        button: CompanionButton,
        router: CompanionInputRouter,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) {
        self.init(button: button, router: router, hapticStyle: hapticStyle) {
            Text(title)
        }
    }
}
