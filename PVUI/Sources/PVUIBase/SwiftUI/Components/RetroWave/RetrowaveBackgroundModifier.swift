//
//  RetrowaveBackgroundModifier.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI
import PVThemes

// MARK: - Retrowave Background Modifier

/// A view modifier that applies a retro-style background with grid lines and scanline effects
public struct RetrowaveBackgroundModifier: ViewModifier {
    @State private var scanlineOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.7
    @ObservedObject private var themeManager = ThemeManager.shared

    let lineSpacing: CGFloat
    let lineColor: Color?

    private var palette: UXThemePalette { themeManager.currentPalette }

    private var backgroundColor: Color {
        Color(palette.gameLibraryBackground)
    }

    private var sunsetGradientColor: Color {
        // Use a subtle accent color for the gradient effect
        palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.3 : 0.1)
    }

    private var scanlineColor: Color {
        // Darker scanlines for light theme, lighter for dark theme
        palette.dark
            ? Color.black.opacity(0.1)
            : Color.white.opacity(0.05)
    }

    private var defaultGridLineColor: Color {
        palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.2 : 0.1)
    }

    public init(lineSpacing: CGFloat = 30, lineColor: Color? = nil) {
        self.lineSpacing = lineSpacing
        self.lineColor = lineColor
    }

    public func body(content: Content) -> some View {
        ZStack {
            // Base background - theme-aware
            backgroundColor.ignoresSafeArea()

            // Sunset gradient - theme-aware
            VStack {
                Spacer()
                Rectangle()
                    .fill(sunsetGradientColor)
                    .frame(height: 200)
                    .offset(y: 100)
                    .blur(radius: 30)
            }
            .ignoresSafeArea()

            // Grid lines - theme-aware
            RetroGrid(
                lineSpacing: lineSpacing,
                lineColor: lineColor ?? defaultGridLineColor
            )
            .ignoresSafeArea()

            // Scanline effect - theme-aware
            VStack(spacing: 4) {
                ForEach(0..<100) { _ in
                    Rectangle()
                        .fill(scanlineColor)
                        .frame(height: 1)
                }
            }
            .offset(y: scanlineOffset)
            .ignoresSafeArea()

            // Content
            content
        }
        .onAppear {
            // Scanline animation
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                scanlineOffset = 4
            }

            // Pulsing glow effect
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

// Extension to make the modifier easier to use
public extension View {
    /// Applies a retro-style background with grid lines and scanline effects
    /// - Parameters:
    ///   - lineSpacing: The spacing between grid lines
    ///   - lineColor: The color of the grid lines (optional, uses theme-aware default if nil)
    /// - Returns: A view with the retrowave background applied
    public func retrowaveBackground(lineSpacing: CGFloat = 30, lineColor: Color? = nil) -> some View {
        self.modifier(RetrowaveBackgroundModifier(lineSpacing: lineSpacing, lineColor: lineColor))
    }
}
