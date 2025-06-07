//
//  ProvenanceButtonStyle.swift
//  UITesting
//
//  Created by Joseph Mattiello on 3/26/25.
//

import SwiftUI
import PVThemes

// MARK: - Custom Button Style

/// A button style that matches the Provenance theme
public struct ProvenanceButtonStyle: ButtonStyle {
    public var isDestructive: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buttonBorderColor(configuration: configuration), lineWidth: 2)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func buttonColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return Color(ThemeManager.shared.currentPalette.defaultTintColor.withAlphaComponent(0.8))
        } else if isDestructive {
            return Color.red.opacity(0.8)
        } else {
            return Color(ThemeManager.shared.currentPalette.defaultTintColor)
        }
    }

    private func buttonBorderColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return Color.white.opacity(0.5)
        } else {
            return Color.white.opacity(0.2)
        }
    }
}

public extension View {
    public func provenanceButton(isDestructive: Bool = false) -> some View {
        self.buttonStyle(ProvenanceButtonStyle(isDestructive: isDestructive))
    }
}
