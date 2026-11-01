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

/// Coordinated accents shared by SwiftUI and UIKit. Dynamic resolution uses the
/// theme manager's synchronized palette snapshot, including off-main UIKit reads.
public enum RetroThemeColors {
    public enum Role: Sendable {
        case primary, secondary, tertiary, background, surface
    }

    public static func color(_ role: Role) -> UIColor {
        UIColor { traits in
            resolvedColor(role, palette: ThemeManager.shared.paletteForColorResolution, traits: traits)
        }
    }

    static func resolvedColor(_ role: Role, palette: any UXThemePalette, traits: UITraitCollection) -> UIColor {
        let tint = palette.defaultTintColor.resolvedColor(with: traits)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        tint.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        switch role {
        case .primary:
            if palette is RetroWaveThemePalette { return UIColor(red: 0.40, green: 0.80, blue: 0.90, alpha: 1) }
            return tint
        case .secondary, .tertiary:
            let shift: CGFloat = role == .secondary ? 0.16 : 0.29
            if palette is RetroWaveThemePalette {
                return role == .secondary
                    ? UIColor(red: 0.69, green: 0.55, blue: 0.91, alpha: 1)
                    : palette.defaultTintColor
            }
            return UIColor(hue: (hue + shift).truncatingRemainder(dividingBy: 1),
                           saturation: min(saturation, palette.dark ? 0.52 : 0.75),
                           brightness: palette.dark ? 0.95 : 0.66, alpha: 1)
        case .background, .surface:
            let base = (role == .background ? palette.gameLibraryBackground
                        : palette.gameLibraryCellBackground ?? palette.gameLibraryHeaderBackground).resolvedColor(with: traits)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            base.getRed(&red, green: &green, blue: &blue, alpha: nil)
            let amount: CGFloat = palette.dark ? (role == .background ? 0.055 : 0.10) : 0.025
            var tintRed: CGFloat = 0
            var tintGreen: CGFloat = 0
            var tintBlue: CGFloat = 0
            tint.getRed(&tintRed, green: &tintGreen, blue: &tintBlue, alpha: nil)
            return UIColor(red: red * (1 - amount) + tintRed * amount,
                           green: green * (1 - amount) + tintGreen * amount,
                           blue: blue * (1 - amount) + tintBlue * amount, alpha: 1)
        }
    }
}

// Retrowave color palette
public extension Color {
    /// Legacy names map to distinct semantic roles in the active theme.
    static var retroPink: Color { Color(RetroThemeColors.color(.tertiary)) }
    static var retroPurple: Color { Color(RetroThemeColors.color(.secondary)) }
    static var retroBlue: Color { Color(RetroThemeColors.color(.primary)) }
    static var retroDarkBlue: Color { Color(RetroThemeColors.color(.surface)) }
    static let retroGreen = Color(red: 0.27, green: 0.90, blue: 0.81)
    static let retroYellow = Color(red: 0.91, green: 0.80, blue: 0.45)
    static let retroOrange = Color(red: 0.98, green: 0.5, blue: 0.2)
    static var retroBlack: Color { Color(RetroThemeColors.color(.background)) }
    static let retroCyan = Color(red: 0.19, green: 0.86, blue: 0.85)
    static let retroBlackClear = Color.black.opacity(0.001)

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
