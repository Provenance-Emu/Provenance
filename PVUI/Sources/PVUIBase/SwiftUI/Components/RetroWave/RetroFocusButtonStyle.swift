//
//  RetroFocusButtonStyle.swift
//  PVUI
//
//  A comprehensive button style for tvOS that combines:
//  - Disabled default tvOS focus effects
//  - Custom retro-themed focus styling with zoom and border gradient
//  - Smooth animations
//
//  Created by Joseph Mattiello on 12/29/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

// MARK: - Retro Focus Button Style

/// A button style optimized for tvOS with RetroWave focus effects
/// Combines focus effect disabling, scale animation, border gradient, and glow
#if os(tvOS)
@available(tvOS 16.0, *)
public struct RetroFocusButtonStyle: ButtonStyle {
    /// Scale factor when focused (default: 1.08)
    public let focusScale: CGFloat
    /// Border width when focused (default: 3)
    public let focusBorderWidth: CGFloat
    /// Corner radius for the border (default: 12)
    public let cornerRadius: CGFloat
    /// Primary glow color (default: retroPink)
    public let primaryColor: Color
    /// Secondary color for gradient (default: retroBlue)
    public let secondaryColor: Color
    /// Glow radius when focused (default: 10)
    public let glowRadius: CGFloat

    public init(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10
    ) {
        self.focusScale = focusScale
        self.focusBorderWidth = focusBorderWidth
        self.cornerRadius = cornerRadius
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.glowRadius = glowRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        RetroFocusButtonContent(
            configuration: configuration,
            focusScale: focusScale,
            focusBorderWidth: focusBorderWidth,
            cornerRadius: cornerRadius,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            glowRadius: glowRadius
        )
    }
}

@available(tvOS 16.0, *)
private struct RetroFocusButtonContent: View {
    let configuration: ButtonStyle.Configuration
    let focusScale: CGFloat
    let focusBorderWidth: CGFloat
    let cornerRadius: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let glowRadius: CGFloat

    @Environment(\.isFocused) private var isFocused: Bool

    private var focusBorderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var clearGradient: LinearGradient {
        LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? focusScale : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isFocused ? focusBorderGradient : clearGradient,
                        lineWidth: isFocused ? focusBorderWidth : 0
                    )
            )
            .shadow(
                color: isFocused ? primaryColor.opacity(0.6) : .clear,
                radius: isFocused ? glowRadius : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .tvOSDisableFocusEffect()
    }
}
#endif

// MARK: - Convenience Extensions

public extension View {
    /// Applies the standard RetroWave focus button styling for tvOS
    /// On iOS/macOS, applies plain button style
    @ViewBuilder
    func retroFocusButtonStyle(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10
    ) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self.buttonStyle(RetroFocusButtonStyle(
                focusScale: focusScale,
                focusBorderWidth: focusBorderWidth,
                cornerRadius: cornerRadius,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                glowRadius: glowRadius
            ))
        } else {
            self.buttonStyle(.plain)
        }
        #else
        self.buttonStyle(.plain)
        #endif
    }
}

// MARK: - Legacy Support View Modifier

/// A view modifier that applies retro focus effects to any focusable view
/// Use this when you need focus effects on non-Button views
#if os(tvOS)
@available(tvOS 16.0, *)
public struct RetroFocusEffectModifier: ViewModifier {
    let focusScale: CGFloat
    let focusBorderWidth: CGFloat
    let cornerRadius: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let glowRadius: CGFloat

    @FocusState private var isFocused: Bool

    public init(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10
    ) {
        self.focusScale = focusScale
        self.focusBorderWidth = focusBorderWidth
        self.cornerRadius = cornerRadius
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.glowRadius = glowRadius
    }

    private var focusBorderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var clearGradient: LinearGradient {
        LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .scaleEffect(isFocused ? focusScale : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isFocused ? focusBorderGradient : clearGradient,
                        lineWidth: isFocused ? focusBorderWidth : 0
                    )
            )
            .shadow(
                color: isFocused ? primaryColor.opacity(0.6) : .clear,
                radius: isFocused ? glowRadius : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
            .tvOSDisableFocusEffect()
    }
}
#endif

public extension View {
    /// Applies retro focus effects (scale, border, glow) to any focusable view
    /// Automatically disables default tvOS focus effect
    @ViewBuilder
    func retroFocusEffect(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10
    ) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self.modifier(RetroFocusEffectModifier(
                focusScale: focusScale,
                focusBorderWidth: focusBorderWidth,
                cornerRadius: cornerRadius,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                glowRadius: glowRadius
            ))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Combined Button + Focus Style Modifier

/// A convenience modifier that combines button style, focus effects, and focus state binding
/// Use when you need external access to the focus state
#if os(tvOS)
@available(tvOS 16.0, *)
public struct RetroFocusableButtonModifier<FocusValue: Hashable>: ViewModifier {
    let focusBinding: FocusState<FocusValue?>.Binding
    let focusValue: FocusValue
    let focusScale: CGFloat
    let focusBorderWidth: CGFloat
    let cornerRadius: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let glowRadius: CGFloat

    private var isFocused: Bool {
        focusBinding.wrappedValue == focusValue
    }

    private var focusBorderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var clearGradient: LinearGradient {
        LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public func body(content: Content) -> some View {
        content
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
            .focused(focusBinding, equals: focusValue)
            .scaleEffect(isFocused ? focusScale : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isFocused ? focusBorderGradient : clearGradient,
                        lineWidth: isFocused ? focusBorderWidth : 0
                    )
            )
            .shadow(
                color: isFocused ? primaryColor.opacity(0.6) : .clear,
                radius: isFocused ? glowRadius : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}
#endif

public extension View {
    /// Applies a complete retro focus button styling with external focus state binding
    /// - Parameters:
    ///   - focusBinding: The FocusState binding to track focus
    ///   - focusValue: The value to compare against the focus binding
    ///   - focusScale: Scale when focused (default: 1.08)
    ///   - cornerRadius: Corner radius for border (default: 12)
    ///   - primaryColor: Primary gradient/glow color (default: retroPink)
    ///   - secondaryColor: Secondary gradient color (default: retroBlue)
    @ViewBuilder
    func retroFocusableButton<FocusValue: Hashable>(
        focused: FocusState<FocusValue?>.Binding,
        equals value: FocusValue,
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10
    ) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self.modifier(RetroFocusableButtonModifier(
                focusBinding: focused,
                focusValue: value,
                focusScale: focusScale,
                focusBorderWidth: focusBorderWidth,
                cornerRadius: cornerRadius,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                glowRadius: glowRadius
            ))
        } else {
            self.buttonStyle(.plain)
        }
        #else
        self.buttonStyle(.plain)
        #endif
    }
}
