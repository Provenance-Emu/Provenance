//
//  RetroFocusButtonStyle.swift
//  PVUI
//
//  A comprehensive button style for tvOS that combines:
//  - Disabled default tvOS focus effects
//  - Custom retro-themed focus styling with zoom and border gradient
//  - Smooth animations
//
//  Usage:
//  - RetroFocusButtonStyle: Full button style with focus handling
//  - retroFocusButtonStyle(): Convenience modifier for buttons
//  - retroFocusableButton(focused:equals:): For buttons with external focus binding
//  - retroFocusEffect(): For non-button focusable views
//  - retroThemedFocus(): Minimal focus indicator that preserves existing button styling
//
//  Created by Joseph Mattiello on 12/29/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

// MARK: - Common Focus Configuration

/// Configuration options for retro focus effects
public struct RetroFocusConfiguration {
    public let focusScale: CGFloat
    public let focusBorderWidth: CGFloat
    public let cornerRadius: CGFloat
    public let primaryColor: Color
    public let secondaryColor: Color
    public let glowRadius: CGFloat
    public let glowOpacity: Double
    public let showBorder: Bool
    public let showGlow: Bool
    public let showScale: Bool

    public static let standard = RetroFocusConfiguration()
    public static let subtle = RetroFocusConfiguration(focusScale: 1.02, focusBorderWidth: 2, glowRadius: 6, glowOpacity: 0.4)
    public static let prominent = RetroFocusConfiguration(focusScale: 1.12, focusBorderWidth: 4, glowRadius: 15, glowOpacity: 0.8)
    public static let borderOnly = RetroFocusConfiguration(focusScale: 1.0, showScale: false)
    public static let glowOnly = RetroFocusConfiguration(focusScale: 1.0, showBorder: false, showScale: false)
    public static let scaleOnly = RetroFocusConfiguration(showBorder: false, showGlow: false)

    public init(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10,
        glowOpacity: Double = 0.6,
        showBorder: Bool = true,
        showGlow: Bool = true,
        showScale: Bool = true
    ) {
        self.focusScale = focusScale
        self.focusBorderWidth = focusBorderWidth
        self.cornerRadius = cornerRadius
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.glowRadius = glowRadius
        self.glowOpacity = glowOpacity
        self.showBorder = showBorder
        self.showGlow = showGlow
        self.showScale = showScale
    }
}

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
    /// Whether to show border on focus (default: true)
    public let showBorder: Bool
    /// Whether to show glow on focus (default: true)
    public let showGlow: Bool
    /// Whether to scale on focus (default: true)
    public let showScale: Bool

    public init(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10,
        showBorder: Bool = true,
        showGlow: Bool = true,
        showScale: Bool = true
    ) {
        self.focusScale = focusScale
        self.focusBorderWidth = focusBorderWidth
        self.cornerRadius = cornerRadius
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.glowRadius = glowRadius
        self.showBorder = showBorder
        self.showGlow = showGlow
        self.showScale = showScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        RetroFocusButtonContent(
            configuration: configuration,
            focusScale: focusScale,
            focusBorderWidth: focusBorderWidth,
            cornerRadius: cornerRadius,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            glowRadius: glowRadius,
            showBorder: showBorder,
            showGlow: showGlow,
            showScale: showScale
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
    let showBorder: Bool
    let showGlow: Bool
    let showScale: Bool

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
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused && showScale ? focusScale : 1.0))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                isFocused ? focusBorderGradient : clearGradient,
                                lineWidth: isFocused ? focusBorderWidth : 0
                            )
                    }
                }
            )
            .shadow(
                color: isFocused && showGlow ? primaryColor.opacity(0.6) : .clear,
                radius: isFocused && showGlow ? glowRadius : 0,
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
    /// - Parameters:
    ///   - focusScale: Scale factor when focused (default: 1.08)
    ///   - focusBorderWidth: Border width when focused (default: 3)
    ///   - cornerRadius: Corner radius for the border (default: 12)
    ///   - primaryColor: Primary glow/border color (default: retroPink)
    ///   - secondaryColor: Secondary gradient color (default: retroBlue)
    ///   - glowRadius: Glow radius when focused (default: 10)
    ///   - showBorder: Whether to show focus border (default: true). Set to false if button has its own border.
    ///   - showGlow: Whether to show focus glow (default: true)
    ///   - showScale: Whether to scale on focus (default: true)
    @ViewBuilder
    func retroFocusButtonStyle(
        focusScale: CGFloat = 1.08,
        focusBorderWidth: CGFloat = 3,
        cornerRadius: CGFloat = 12,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 10,
        showBorder: Bool = true,
        showGlow: Bool = true,
        showScale: Bool = true
    ) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self.buttonStyle(RetroFocusButtonStyle(
                focusScale: focusScale,
                focusBorderWidth: focusBorderWidth,
                cornerRadius: cornerRadius,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                glowRadius: glowRadius,
                showBorder: showBorder,
                showGlow: showGlow,
                showScale: showScale
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
    let showBorder: Bool

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
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                isFocused ? focusBorderGradient : clearGradient,
                                lineWidth: isFocused ? focusBorderWidth : 0
                            )
                    }
                }
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
        glowRadius: CGFloat = 10,
        showBorder: Bool = true
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
                glowRadius: glowRadius,
                showBorder: showBorder
            ))
        } else {
            self.buttonStyle(.plain)
        }
        #else
        self.buttonStyle(.plain)
        #endif
    }
}

// MARK: - Themed Focus Modifier (Minimal - Preserves Existing Button Style)

/// A lightweight focus modifier that adds focus effects WITHOUT overriding existing button styling
/// Use this when you have a custom ButtonStyle and just want to add focus indicators
/// The button's existing appearance is preserved, only focus effects are added
#if os(tvOS)
@available(tvOS 16.0, *)
public struct RetroThemedFocusModifier: ViewModifier {
    let config: RetroFocusConfiguration

    @Environment(\.isFocused) private var isFocused: Bool

    public init(config: RetroFocusConfiguration = .standard) {
        self.config = config
    }

    public init(
        focusScale: CGFloat = 1.05,
        focusBorderWidth: CGFloat = 2.5,
        cornerRadius: CGFloat = 8,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 8,
        glowOpacity: Double = 0.5
    ) {
        self.config = RetroFocusConfiguration(
            focusScale: focusScale,
            focusBorderWidth: focusBorderWidth,
            cornerRadius: cornerRadius,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            glowRadius: glowRadius,
            glowOpacity: glowOpacity
        )
    }

    private var focusBorderGradient: LinearGradient {
        LinearGradient(
            colors: [config.primaryColor, config.secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(config.showScale && isFocused ? config.focusScale : 1.0)
            .overlay(
                Group {
                    if config.showBorder {
                        RoundedRectangle(cornerRadius: config.cornerRadius)
                            .strokeBorder(
                                isFocused ? focusBorderGradient : LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: isFocused ? config.focusBorderWidth : 0
                            )
                    }
                }
            )
            .shadow(
                color: config.showGlow && isFocused ? config.primaryColor.opacity(config.glowOpacity) : .clear,
                radius: isFocused ? config.glowRadius : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

/// A wrapper view that enables focus for Button while preserving any existing ButtonStyle
@available(tvOS 16.0, *)
public struct RetroThemedFocusButtonWrapper<Content: View>: View {
    let config: RetroFocusConfiguration
    let content: Content

    @Environment(\.isFocused) private var envFocused: Bool
    @FocusState private var isFocused: Bool

    private var effectiveFocus: Bool {
        isFocused || envFocused
    }

    public init(config: RetroFocusConfiguration = .standard, @ViewBuilder content: () -> Content) {
        self.config = config
        self.content = content()
    }

    private var focusBorderGradient: LinearGradient {
        LinearGradient(
            colors: [config.primaryColor, config.secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var body: some View {
        content
            .focused($isFocused)
            .tvOSDisableFocusEffect()
            .scaleEffect(config.showScale && effectiveFocus ? config.focusScale : 1.0)
            .overlay(
                Group {
                    if config.showBorder {
                        RoundedRectangle(cornerRadius: config.cornerRadius)
                            .strokeBorder(
                                effectiveFocus ? focusBorderGradient : LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: effectiveFocus ? config.focusBorderWidth : 0
                            )
                    }
                }
            )
            .shadow(
                color: config.showGlow && effectiveFocus ? config.primaryColor.opacity(config.glowOpacity) : .clear,
                radius: effectiveFocus ? config.glowRadius : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: effectiveFocus)
    }
}
#endif

public extension View {
    /// Adds retro focus effects to a Button while preserving its existing ButtonStyle
    /// This is a lightweight modifier that only adds visual focus feedback
    /// Use this for themed buttons that already have custom styling
    @ViewBuilder
    func retroThemedFocus(
        focusScale: CGFloat = 1.05,
        focusBorderWidth: CGFloat = 2.5,
        cornerRadius: CGFloat = 8,
        primaryColor: Color = .retroPink,
        secondaryColor: Color = .retroBlue,
        glowRadius: CGFloat = 8,
        glowOpacity: Double = 0.5
    ) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self
                .tvOSDisableFocusEffect()
                .modifier(RetroThemedFocusModifier(
                    focusScale: focusScale,
                    focusBorderWidth: focusBorderWidth,
                    cornerRadius: cornerRadius,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    glowRadius: glowRadius,
                    glowOpacity: glowOpacity
                ))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Adds retro focus effects using a predefined configuration
    @ViewBuilder
    func retroThemedFocus(config: RetroFocusConfiguration) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self
                .tvOSDisableFocusEffect()
                .modifier(RetroThemedFocusModifier(config: config))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Convenience Wrappers for Settings Rows

public extension View {
    /// Wraps the view in a retro-themed focusable container
    /// Use this for settings rows and list items that need focus feedback
    @ViewBuilder
    func retroSettingsRowFocus(cornerRadius: CGFloat = 8) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            RetroThemedFocusButtonWrapper(
                config: RetroFocusConfiguration(
                    focusScale: 1.02,
                    focusBorderWidth: 2,
                    cornerRadius: cornerRadius,
                    primaryColor: .retroPink,
                    secondaryColor: .retroBlue,
                    glowRadius: 6,
                    glowOpacity: 0.4
                )
            ) {
                self
            }
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// For theme selection rows that have their own selected state
    /// Adds focus effects that complement the existing selection styling
    @ViewBuilder
    func retroThemeRowFocus(isSelected: Bool, cornerRadius: CGFloat = 8) -> some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            self
                .tvOSDisableFocusEffect()
                .modifier(RetroThemedFocusModifier(
                    config: RetroFocusConfiguration(
                        focusScale: isSelected ? 1.02 : 1.04,
                        focusBorderWidth: isSelected ? 3 : 2,
                        cornerRadius: cornerRadius,
                        primaryColor: .retroPink,
                        secondaryColor: .retroBlue,
                        glowRadius: isSelected ? 10 : 6,
                        glowOpacity: isSelected ? 0.6 : 0.4
                    )
                ))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
