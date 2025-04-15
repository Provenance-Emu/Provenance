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
    }
}

/// A button style specifically for tvOS buttons that need focus indicators
public struct TVFocusableButtonStyle: ButtonStyle {
    private let colors: [Color]
    private let glowColor: Color
    
    public init(colors: [Color], glowColor: Color? = nil) {
        self.colors = colors
        self.glowColor = glowColor ?? (colors.first ?? .retroPink)
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        TVFocusableButton(configuration: configuration, colors: colors, glowColor: glowColor)
    }
    
    private struct TVFocusableButton: View {
        @Environment(\.isFocused) private var isFocused: Bool
        let configuration: ButtonStyle.Configuration
        let colors: [Color]
        let glowColor: Color
        
        var body: some View {
            configuration.label
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: colors),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: isFocused ? 3 : 1.5
                                )
                        )
                )
                .shadow(color: glowColor.opacity(isFocused ? 0.9 : 0.0), radius: isFocused ? 8 : 0)
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .brightness(configuration.isPressed ? 0.1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

/// Extension to add a modifier that enhances tvOS buttons with focus effects
public extension View {
    /// Adds tvOS-specific focus enhancements to buttons
    /// - Parameter glowColor: The color to use for the focus glow effect
    /// - Returns: A modified view with enhanced focus effects on tvOS
    func tvOSFocusEnhancement(glowColor: Color) -> some View {
        #if os(tvOS)
        self
            .buttonStyle(TVFocusableButtonStyle(colors: [glowColor, glowColor.opacity(0.7)], glowColor: glowColor))
            .focusable(true)
            .padding(.vertical, 8) // Add more padding for tvOS remote navigation
        #else
        self
        #endif
    }
}
#endif
