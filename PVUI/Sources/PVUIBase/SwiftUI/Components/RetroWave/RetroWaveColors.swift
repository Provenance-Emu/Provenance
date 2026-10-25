//
//  RetroWaveColors.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI
import UIKit
import PVThemes

// MARK: - Retrowave Design System

// Retrowave color palette
public extension Color {
    /// Legacy accent names resolve through the active palette so shared controls follow paid themes.
    public static var retroPink: Color { paletteColor { $0.defaultTintColor } }
    public static var retroPurple: Color {
        paletteColor { palette in
            palette is RetroWaveThemePalette ? UIColor(red: 0.69, green: 0.55, blue: 0.91, alpha: 1) : palette.defaultTintColor
        }
    }
    public static var retroBlue: Color {
        paletteColor { palette in
            palette is RetroWaveThemePalette ? UIColor(red: 0.40, green: 0.80, blue: 0.90, alpha: 1) : palette.defaultTintColor
        }
    }
    public static var retroDarkBlue: Color { paletteColor { $0.gameLibraryCellBackground ?? $0.gameLibraryHeaderBackground } }
    public static let retroGreen = Color(red: 0.0, green: 0.95, blue: 0.8)
    public static let retroYellow = Color(red: 0.98, green: 0.84, blue: 0.2)
    public static let retroOrange = Color(red: 0.98, green: 0.5, blue: 0.2)
    public static var retroBlack: Color { paletteColor { $0.gameLibraryBackground } }
    public static let retroCyan = Color(red: 0.0, green: 0.95, blue: 0.95)
    public static let retroBlackClear = Color.black.opacity(0.001)

    private static func paletteColor(_ color: @escaping @Sendable (any UXThemePalette) -> UIColor) -> Color {
        Color(UIColor { _ in color(ThemeManager.shared.paletteForColorResolution) })
    }

    // Gradient helpers
    public static let retroSunset = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let retroGrid = LinearGradient(
        gradient: Gradient(colors: [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let retroNeon = LinearGradient(
        gradient: Gradient(colors: [.retroPink, .retroPurple]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let retroCyber = LinearGradient(
        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradient helpers
    public static let retroGradient = LinearGradient(
        gradient: Gradient(colors: [.retroPurple, .retroPink]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let retroSunsetGradient = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
}
