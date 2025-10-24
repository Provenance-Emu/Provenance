//
//  GradientButtonStyle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI

// MARK: - Custom UI Components

public struct GradientButtonStyle: ButtonStyle {
    public let colors: [Color]
    public let glowColor: Color
    public let textShadow: Bool
    
    public init(colors: [Color], glowColor: Color? = nil, textShadow: Bool = true) {
        self.colors = colors
        self.glowColor = glowColor ?? (colors.first ?? .retroPink)
        self.textShadow = textShadow
    }
    
    public func makeBody(configuration: Configuration) -> some View {
#if os(tvOS)
        GradientButtonStyleBody(configuration: configuration, colors: colors, glowColor: glowColor, textShadow: textShadow)
#else
        configuration.label
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .tracking(1.2) // Letter spacing for that retro look
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Grid overlay
                    RetroGrid(lineSpacing: 8, lineColor: .white.opacity(0.15))
                }
            )
            .foregroundColor(.white)
            .ifApply(textShadow) { view in
                view.shadow(color: glowColor.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                    .shadow(color: glowColor.opacity(0.4), radius: 0, x: 3, y: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [colors.last ?? .white, colors.first ?? .white]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(8)
            .shadow(color: glowColor.opacity(0.6), radius: 8, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
#endif
    }
}

#if os(tvOS)
/// Implementation of GradientButtonStyle for tvOS with focus support
private struct GradientButtonStyleBody: View {
    @Environment(\.isFocused) private var isFocused: Bool
    let configuration: ButtonStyle.Configuration
    let colors: [Color]
    let glowColor: Color
    let textShadow: Bool
    
    var body: some View {
        configuration.label
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .tracking(1.2) // Letter spacing for that retro look
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Grid overlay
                    RetroGrid(lineSpacing: 8, lineColor: .white.opacity(0.15))
                }
            )
            .foregroundColor(.white)
            .ifApply(textShadow) { view in
                view.shadow(color: glowColor.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                    .shadow(color: glowColor.opacity(0.4), radius: 0, x: 3, y: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [colors.last ?? .white, colors.first ?? .white]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: isFocused ? 3 : 1.5
                    )
            )
            .cornerRadius(8)
            .shadow(color: glowColor.opacity(isFocused ? 0.9 : 0.6), radius: isFocused ? 12 : 8, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.05 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            // Make sure the button is focusable on tvOS
            .focusable(true)
            // Add vertical padding for better tvOS navigation
            .padding(.vertical, 8)
    }
}

// This style is no longer needed since GradientButtonStyle now handles tvOS focus

// This extension is no longer needed since GradientButtonStyle now handles tvOS focus
#endif
