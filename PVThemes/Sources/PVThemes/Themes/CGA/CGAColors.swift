//
//  CGAColors.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

// TODO: Move this to a moudle, use a macro to generate colors

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#elseif canImport(AppKit)
import AppKit
#endif
import HexColors

public enum CGAThemes: String, CaseIterable, PaletteProvider {
    case blue
    case cyan
    case green
    case magenta
    case red
    case yellow
    case purple
    case rainbow
    case random

    public var palette: any UXThemePalette {
        let palette: any UXThemePalette
        switch self {
        case .blue:
            palette = CGABlueThemePalette()
        case .cyan:
            palette = CGACyanThemePalette()
        case .green:
            palette = CGAGreenThemePalette()
        case .magenta:
            palette = CGAMagentaThemePalette()
        case .red:
            palette = CGARedThemePalette()
        case .yellow:
            palette = CGAYellowThemePalette()
        case .purple:
            palette = CGAPurpleThemePalette()
        case .rainbow:
            palette = CGARainbowThemePalette()
        case .random:
            palette = CGARandomThemePalette()
        }
        return palette
    }
}

public extension UIColor {
    enum CGA: CaseIterable {
#if canImport(UIKit)
        public static let blue: UIColor         = #uiColor(0x0000AA)
        public static let blueShadow: UIColor   = #uiColor(0x0000FF)

        public static let cyan: UIColor         = #uiColor(0x00AAAA)
        public static let cyanShadow: UIColor   = #uiColor(0x00FFFF)

        public static let green: UIColor        = #uiColor(0x00AA00)
        public static let greenShadow: UIColor  = #uiColor(0x00FF00)

        public static let magenta: UIColor      = #uiColor(0xAA00AA)
        public static let magentaShadow: UIColor = #uiColor(0xFF00FF)

        public static let red: UIColor          = #uiColor(0xAA0000)
        public static let redShadow: UIColor    = #uiColor(0xFF0000)

        public static let yellow: UIColor       = #uiColor(0xAAAA00)
        public static let yellowShadow: UIColor = #uiColor(0xFFFF00)

        public static let purple: UIColor       = #uiColor(0xDD33FF)
        public static let purpleShadow: UIColor = #uiColor(0x6B1383)

        static public var allCases: [UIColor] {
            [.CGA.blue, .CGA.blueShadow, .CGA.cyan, .CGA.cyanShadow, .CGA.green, .CGA.greenShadow, .CGA.magenta, .CGA.magentaShadow, .CGA.red, .CGA.redShadow, .CGA.yellow, .CGA.yellowShadow, .CGA.purple, .CGA.purpleShadow]
        }

        static public func random() -> UIColor {
            allCases.randomElement()!
        }
#else
        public static let blue: UIColor         = #nsColor(0x0000AA)
        public static let blueShadow: UIColor   = #nsColor(0x0000FF)

        public static let cyan: UIColor         = #nsColor(0x00AAAA)
        public static let cyanShadow: UIColor   = #nsColor(0x00FFFF)

        public static let green: UIColor        = #nsColor(0x00AA00)
        public static let greenShadow: UIColor  = #nsColor(0x00FF00)

        public static let magenta: UIColor      = #nsColor(0xAA00AA)
        public static let magentaShadow: UIColor = #nsColor(0xFF00FF)

        public static let red: UIColor          = #nsColor(0xAA0000)
        public static let redShadow: UIColor    = #nsColor(0xFF0000)

        public static let yellow: UIColor       = #nsColor(0xAAAA00)
        public static let yellowShadow: UIColor = #nsColor(0xFFFF00)

        public static let purple: UIColor       = #nsColor(0xDD33FF)
        public static let purpleShadow: UIColor = #nsColor(0x6B1383)
#endif
    }
}

public struct CGAGreenThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Green" }
    public var group: String { "CGA" }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.green }
#endif
    public var defaultTintColor: UIColor { .CGA.green }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    /// Switches
    public var switchThumb: UIColor? { .CGA.greenShadow }
    public var switchON: UIColor? { .CGA.green }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.greenShadow.brightness(0.10) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.green.brightness(1.0) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor { .CGA.greenShadow.brightness(0.20) }
    ///         Text
    public var gameLibraryCellText: UIColor { .CGA.green.brightness(1.0) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.green.withAlphaComponent(0.20) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.green }

    /// Navigation Bar
    ///     Background Color
    public var navigationBarBackgroundColor: UIColor? { .CGA.greenShadow }
    ///     Item Tint
    public var barButtonItemTint: UIColor? { .CGA.green }

    /// Settings
    ///     Header Background
    public var settingsHeaderBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
    ///     Header Text
    public var settingsHeaderText: UIColor? { .CGA.green }
    ///     Cell Background
    public var settingsCellBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
    ///     Cell Text
    public var settingsCellText: UIColor? { .CGA.green }

    ///  Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.green.brightness(0.2) }
    ///     Text
    public var menuText: UIColor { .CGA.greenShadow }
    ///     Divider
    public var menuDivider: UIColor { .CGA.green.brightness(0.4) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.greenShadow }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor  { .CGA.green.brightness(0.3) }
    ///         Tint
    public var menuHeaderIconTint: UIColor { .CGA.greenShadow }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor  { .CGA.green.brightness(0.3) }
    ///         Tint
    public var menuSectionHeaderIconTint: UIColor { .CGA.green }
}

public struct CGABlueThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Blue" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundAlpha: CGFloat { 0.95 }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.blue }
#endif
    public var defaultTintColor: UIColor { .CGA.blue.addSaturation(1.0).brightness(1.0) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    public var switchThumb: UIColor? { .CGA.blueShadow }
    public var switchON: UIColor? { .CGA.blue }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.blueShadow.brightness(0.1) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.blue }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.blueShadow.brightness(0.10) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.blue.addSaturation(1.0).brightness(1.0) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.blueShadow.brightness(0.10) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.blue.addSaturation(1.0).brightness(1.0) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? {  .CGA.blueShadow.brightness(0.10) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? {.CGA.blue.addSaturation(1.0).brightness(1.0)  }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .black }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.blue }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.blueShadow.brightness(0.2) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.blue }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.blue.brightness(0.2) }
    ///     Text
    public var menuText: UIColor { .CGA.blueShadow }
    ///     Divider
    public var menuDivider: UIColor { .CGA.blue.brightness(0.4) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.blueShadow }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.blue.brightness(0.3) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.blueShadow }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { .CGA.blue.brightness(0.3) }
    ///         Text
    public var menuSectionHeaderText: UIColor { .CGA.blueShadow.brightness(0.5) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor {.CGA.blueShadow }
}

public struct CGACyanThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Cyan" }
    public var group: String { "CGA" }
    public var dark: Bool { false }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.cyan }
#endif
    public var defaultTintColor: UIColor { .CGA.cyan }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    public var switchThumb: UIColor? { .CGA.cyanShadow }
    public var switchON: UIColor? { .CGA.cyan }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.cyanShadow.brightness(0.97).saturation(0.15) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.cyan }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.cyanShadow }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .black }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { gameLibraryBackground }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.cyan }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.cyanShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.cyan }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.cyanShadow }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.cyan.brightness(1.0) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.cyanShadow.brightness(0.95).saturation(0.10) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.cyan }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.cyan.brightness(0.7) }
    ///     Text
    public var menuText: UIColor { .CGA.cyan.brightness(1.0) }
    ///     Divider
    public var menuDivider: UIColor { .CGA.cyan.brightness(0.6) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.cyanShadow.brightness(1.0) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.cyanShadow.brightness(0.7) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.cyan.brightness(1.0) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { .CGA.cyan.brightness(0.3) }
    ///         Text
    public var menuSectionHeaderText: UIColor { .CGA.cyanShadow.brightness(0.5) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { .CGA.cyan }
}

public struct CGAPurpleThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Purple" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundBrightness: CGFloat = 0.05
    var backgroundAlpha: CGFloat { 0.95 }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.purple }
#endif
    public var defaultTintColor: UIColor { .CGA.purple }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { .CGA.purpleShadow }
    public var switchON: UIColor? { .CGA.purple }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.purpleShadow.brightness(backgroundBrightness) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.purple }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.purpleShadow }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.purple }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.purpleShadow.brightness(0.10) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.purple }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.purpleShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.purple }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.purpleShadow.brightness(backgroundBrightness) }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.purple }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.purpleShadow.brightness(backgroundBrightness) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.purple }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.purple.brightness(0.2) }
    ///     Text
    public var menuText: UIColor { .CGA.purple }
    ///     Divider
    public var menuDivider: UIColor { .CGA.purple.brightness(0.4) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.purple }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.purple.brightness(0.3) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.purpleShadow }
}

public struct CGAMagentaThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Magenta" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundBrightness: CGFloat { 0.05 }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.magenta }
#endif
    public var defaultTintColor: UIColor { .CGA.magenta }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { .CGA.magentaShadow }
    public var switchON: UIColor? { .CGA.magenta }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.magentaShadow.brightness(backgroundBrightness) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.magenta }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.magentaShadow.withAlphaComponent(0.2) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.magenta }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.magentaShadow.brightness(0.10) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.magenta }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.magentaShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.magenta }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.magentaShadow }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.magenta }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.magentaShadow.brightness(0.2) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.magenta }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.magenta.brightness(0.2) }
    ///     Text
    public var menuText: UIColor { .CGA.magentaShadow }
    ///     Divider
    public var menuDivider: UIColor { .CGA.magenta.brightness(0.4) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.magentaShadow }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.magenta.brightness(0.3) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.magentaShadow }
}

public struct CGARedThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Red" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.red }
#endif
    public var defaultTintColor: UIColor { .CGA.red }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    public var switchThumb: UIColor? { .CGA.redShadow }
    public var switchON: UIColor? { .CGA.red }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.redShadow.brightness(0.2) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.red }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.redShadow.brightness(0.25) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.red.brightness(1.0) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.redShadow.brightness(0.20) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.red.brightness(1.0) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.redShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.red.brightness(1.0) }

    /// Settings
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.redShadow.brightness(0.2) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.red }
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.redShadow }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.red }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.redShadow.brightness(0.3) }
    ///     Text
    public var menuText: UIColor { .CGA.red.brightness(1.0) }
    ///     Divider
    public var menuDivider: UIColor { .CGA.red.brightness(0.6) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.red.brightness(1.0) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.redShadow.brightness(0.3) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.red.brightness(1.0) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor {  .CGA.redShadow.brightness(0.2) }
    ///         Text
    public var menuSectionHeaderText: UIColor { .CGA.red.brightness(1.0) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { .CGA.red.brightness(1.0)  }
}

public struct CGAYellowThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Yellow" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.yellow }
#endif
    public var defaultTintColor: UIColor { .CGA.yellow }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif

    public var switchThumb: UIColor? { .CGA.yellowShadow }
    public var switchON: UIColor? { .CGA.yellow }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.yellowShadow.brightness(0.2) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.yellow }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.yellowShadow.brightness(0.9) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.yellow }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.yellowShadow.brightness(0.10) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.yellow }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.yellowShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.yellow }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.yellowShadow }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.yellow }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.yellowShadow.brightness(0.2) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.yellow }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.yellow.brightness(0.20) }
    ///     Text
    public var menuText: UIColor { .CGA.yellow.brightness(1.0) }
    ///     Divider
    public var menuDivider: UIColor { .CGA.yellow.brightness(0.6) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.yellow.brightness(1.0) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.yellow.brightness(0.5) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.yellowShadow.brightness(2.0) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor {  .CGA.yellowShadow.brightness(0.1) }
    ///         Text
    public var menuSectionHeaderText: UIColor { .CGA.yellow.brightness(1.0) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { .CGA.yellow.brightness(1.0)  }
}

public struct CGARainbowThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Rainbow" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundBrightness: CGFloat { 0.90 }
    var backgroundAlpha: CGFloat { 0.95 }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.blue }
#endif
    public var defaultTintColor: UIColor { .CGA.cyan }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { .CGA.yellowShadow }
    public var switchON: UIColor? { .CGA.green }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { .CGA.blueShadow.brightness(0.1) }
    ///     Text
    public var gameLibraryText: UIColor { .CGA.yellow }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { .CGA.purpleShadow }
    ///         Text
    public var gameLibraryHeaderText: UIColor { .CGA.magenta }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { .CGA.redShadow.brightness(0.2) }
    ///         Text
    public var gameLibraryCellText: UIColor? { .CGA.cyan }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { .CGA.redShadow }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { .CGA.cyan }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { .CGA.greenShadow.brightness(0.1) }
    ///         Text
    public var settingsHeaderText: UIColor? { .CGA.yellow }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { .CGA.magentaShadow.brightness(0.2) }
    ///         Text
    public var settingsCellText: UIColor? { .CGA.cyan }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { .CGA.yellow.brightness(0.2) }
    ///     Text
    public var menuText: UIColor { .CGA.redShadow }
    ///     Divider
    public var menuDivider: UIColor { .CGA.red.brightness(0.4) }
    ///     Icon Tint
    public var menuIconTint: UIColor { .CGA.greenShadow }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .CGA.blue.brightness(0.3) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .CGA.cyanShadow }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor  { .CGA.green.brightness(0.3) }
    ///         Tint
    public var menuSectionHeaderIconTint: UIColor { .CGA.purple }
}


public struct CGARandomThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Random" }
    public var group: String { "CGA" }
    public var dark: Bool { _dark }

    private let _dark: Bool
    private let _statusBarColor: Int
    private let _defaultTintColor: Int
    private let _switchThumb: Int?
    private let _switchON: Int?
    private let _gameLibraryBackground: Int
    private let _gameLibraryText: Int
    private let _gameLibraryHeaderBackground: Int
    private let _gameLibraryHeaderText: Int
    private let _gameLibraryCellBackground: Int?
    private let _gameLibraryCellText: Int?
    private let _navigationBarBackgroundColor: Int?
    private let _barButtonItemTint: Int?
    private let _settingsHeaderBackground: Int?
    private let _settingsHeaderText: Int?
    private let _settingsCellBackground: Int?
    private let _settingsCellText: Int?
    private let _menuBackground: Int
    private let _menuText: Int
    private let _menuDivider: Int
    private let _menuIconTint: Int
    private let _menuHeaderBackground: Int
    private let _menuHeaderIconTint: Int
    private let _menuSectionHeaderBackground: Int
    private let _menuSectionHeaderText: Int
    private let _menuSectionHeaderIconTint: Int

#if !os(tvOS)
    public var statusBarColor: UIColor { UIColor(rgb: _statusBarColor) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: _defaultTintColor) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { dark ? .dark : .light }
#endif

    public var switchThumb: UIColor? { _switchThumb.map { UIColor(rgb: $0) } }
    public var switchON: UIColor? { _switchON.map { UIColor(rgb: $0) } }

    // Game Library
    public var gameLibraryBackground: UIColor { UIColor(rgb: _gameLibraryBackground) }
    public var gameLibraryText: UIColor {
        let background = UIColor(rgb: _gameLibraryBackground)
        let text = UIColor(rgb: _gameLibraryText)
        return adjustBrightness(text: text, background: background)
    }
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: _gameLibraryHeaderBackground) }
    public var gameLibraryHeaderText: UIColor {
        let background = UIColor(rgb: _gameLibraryHeaderBackground)
        let text = UIColor(rgb: _gameLibraryHeaderText)
        return adjustBrightness(text: text, background: background)
    }
    public var gameLibraryCellBackground: UIColor? { _gameLibraryCellBackground.map { UIColor(rgb: $0) } }
    public var gameLibraryCellText: UIColor? {
        guard let cellBackground = _gameLibraryCellBackground.map({ UIColor(rgb: $0) }),
              let cellText = _gameLibraryCellText.map({ UIColor(rgb: $0) }) else { return nil }
        return adjustBrightness(text: cellText, background: cellBackground)
    }

    // Navigation Bar
    public var navigationBarBackgroundColor: UIColor? { _navigationBarBackgroundColor.map { UIColor(rgb: $0) } }
    public var barButtonItemTint: UIColor? {
        guard let background = _navigationBarBackgroundColor.map({ UIColor(rgb: $0) }),
              let tint = _barButtonItemTint.map({ UIColor(rgb: $0) }) else { return nil }
        return adjustBrightness(text: tint, background: background)
    }

    // Settings
    public var settingsHeaderBackground: UIColor? { _settingsHeaderBackground.map { UIColor(rgb: $0) } }
    public var settingsHeaderText: UIColor? {
        guard let background = _settingsHeaderBackground.map({ UIColor(rgb: $0) }),
              let text = _settingsHeaderText.map({ UIColor(rgb: $0) }) else { return nil }
        return adjustBrightness(text: text, background: background)
    }
    public var settingsCellBackground: UIColor? { _settingsCellBackground.map { UIColor(rgb: $0) } }
    public var settingsCellText: UIColor? {
        guard let background = _settingsCellBackground.map({ UIColor(rgb: $0) }),
              let text = _settingsCellText.map({ UIColor(rgb: $0) }) else { return nil }
        return adjustBrightness(text: text, background: background)
    }

    // Menu
    public var menuBackground: UIColor { UIColor(rgb: _menuBackground) }
    public var menuText: UIColor {
        let background = UIColor(rgb: _menuBackground)
        let text = UIColor(rgb: _menuText)
        return adjustBrightness(text: text, background: background)
    }
    public var menuDivider: UIColor { UIColor(rgb: _menuDivider) }
    public var menuIconTint: UIColor {
        let background = UIColor(rgb: _menuBackground)
        let tint = UIColor(rgb: _menuIconTint)
        return adjustBrightness(text: tint, background: background)
    }
    public var menuHeaderBackground: UIColor { UIColor(rgb: _menuHeaderBackground) }
    public var menuHeaderIconTint: UIColor {
        let background = UIColor(rgb: _menuHeaderBackground)
        let tint = UIColor(rgb: _menuHeaderIconTint)
        return adjustBrightness(text: tint, background: background)
    }
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: _menuSectionHeaderBackground) }
    public var menuSectionHeaderText: UIColor {
        let background = UIColor(rgb: _menuSectionHeaderBackground)
        let text = UIColor(rgb: _menuSectionHeaderText)
        return adjustBrightness(text: text, background: background)
    }
    public var menuSectionHeaderIconTint: UIColor {
        let background = UIColor(rgb: _menuSectionHeaderBackground)
        let tint = UIColor(rgb: _menuSectionHeaderIconTint)
        return adjustBrightness(text: tint, background: background)
    }

    public init() {
        self._dark = Bool.random()
        self._statusBarColor = UIColor.CGA.allCases.randomElement()!.rgb
        self._defaultTintColor = UIColor.CGA.allCases.randomElement()!.rgb
        self._switchThumb = UIColor.CGA.allCases.randomElement()!.rgb
        self._switchON = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryText = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryHeaderBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryHeaderText = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryCellBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._gameLibraryCellText = UIColor.CGA.allCases.randomElement()!.rgb
        self._navigationBarBackgroundColor = UIColor.CGA.allCases.randomElement()!.rgb
        self._barButtonItemTint = UIColor.CGA.allCases.randomElement()!.rgb
        self._settingsHeaderBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._settingsHeaderText = UIColor.CGA.allCases.randomElement()!.rgb
        self._settingsCellBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._settingsCellText = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuText = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuDivider = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuIconTint = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuHeaderBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuHeaderIconTint = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuSectionHeaderBackground = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuSectionHeaderText = UIColor.CGA.allCases.randomElement()!.rgb
        self._menuSectionHeaderIconTint = UIColor.CGA.allCases.randomElement()!.rgb
    }

    private func adjustBrightness(text: UIColor, background: UIColor) -> UIColor {
        var textBrightness: CGFloat = 0
        var backgroundBrightness: CGFloat = 0
        text.getHue(nil, saturation: nil, brightness: &textBrightness, alpha: nil)
        background.getHue(nil, saturation: nil, brightness: &backgroundBrightness, alpha: nil)

        if abs(textBrightness - backgroundBrightness) < 0.5 {
            return textBrightness > backgroundBrightness ? text.brightness(1.0) : text.brightness(0.0)
        }
        return text
    }
}

private extension UIColor {
    var rgb: Int {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255) << 16
        let g = Int(green * 255) << 8
        let b = Int(blue * 255)

        return r | g | b
    }

    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
