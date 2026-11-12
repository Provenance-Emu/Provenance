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
    public var statusBarColor: UIColor? { UIColor(rgb: 0x101B19) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0x70D6A0) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    /// Switches
    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0x70D6A0) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x101B19) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x1B2C26) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x1B2C26) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0x70D6A0) }

    /// Navigation Bar
    ///     Background Color
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x101B19) }
    ///     Item Tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0x70D6A0) }

    /// Settings
    ///     Header Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x1B2C26) }
    ///     Header Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0x70D6A0) }
    ///     Cell Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x1B2C26) }
    ///     Cell Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }

    ///  Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x101B19) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0x70D6A0) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor  { UIColor(rgb: 0x1B2C26) }
    ///         Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0x70D6A0) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor  { UIColor(rgb: 0x1B2C26) }
    ///         Tint
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0x70D6A0) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x101B19) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x101B19) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x101B19) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0x70D6A0) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0x70D6A0) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0x70D6A0) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

public struct CGABlueThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Blue" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundAlpha: CGFloat { 0.95 }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0x111923) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0x8EB8FF) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0x8EB8FF) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x111923) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x1D2A3C) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0x8EB8FF) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x1D2A3C) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x111923) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0x8EB8FF) }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x1D2A3C) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0x8EB8FF) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x1D2A3C) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x111923) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0x8EB8FF) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0x1D2A3C) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0x8EB8FF) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0x1D2A3C) }
    ///         Text
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0x8EB8FF) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0x8EB8FF) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x111923) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x111923) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x111923) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0x8EB8FF) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0x8EB8FF) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

public struct CGACyanThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Cyan" }
    public var group: String { "CGA" }
    public var dark: Bool { false }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0xEDF7F5) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0x08766F) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0x08766F) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0xEDF7F5) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0x182E2C) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0xFFFFFF) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0x08766F) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0xFFFFFF) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0x182E2C) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0xEDF7F5) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0x08766F) }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0xFFFFFF) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0x08766F) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0xFFFFFF) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0x182E2C) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0xEDF7F5) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0x182E2C) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0x182E2C).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0x08766F) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0xFFFFFF) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0x08766F) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0xFFFFFF) }
    ///         Text
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0x08766F) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0x08766F) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0xEDF7F5) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0xEDF7F5) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0xEDF7F5) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0x182E2C) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0x182E2C) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0x08766F) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0x08766F) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0x4C6764) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0x182E2C).withAlphaComponent(0.14) }
}

public struct CGAPurpleThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Purple" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundBrightness: CGFloat = 0.05
    var backgroundAlpha: CGFloat { 0.95 }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0x1A1624) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0xC6ABFA) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0xC6ABFA) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x1A1624) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x2A2238) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0xC6ABFA) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x2A2238) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x1A1624) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0xC6ABFA) }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x2A2238) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0xC6ABFA) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x2A2238) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x1A1624) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0xC6ABFA) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0x2A2238) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0xC6ABFA) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x1A1624) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x1A1624) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x1A1624) }
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0x2A2238) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0xC6ABFA) }
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0xC6ABFA) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0xC6ABFA) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0xC6ABFA) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

public struct CGAMagentaThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Magenta" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

    var backgroundBrightness: CGFloat { 0.05 }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0x211720) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0xED9CC6) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0xED9CC6) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x211720) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x352532) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0xED9CC6) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x352532) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x211720) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0xED9CC6) }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x352532) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0xED9CC6) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x352532) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x211720) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0xED9CC6) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0x352532) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0xED9CC6) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x211720) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x211720) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x211720) }
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0x352532) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0xED9CC6) }
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0xED9CC6) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0xED9CC6) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0xED9CC6) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

public struct CGARedThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Red" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0x231818) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0xF5A097) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0xF5A097) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x231818) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x392625) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0xF5A097) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x392625) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x231818) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0xF5A097) }

    /// Settings
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x392625) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x392625) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0xF5A097) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x231818) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0xF5A097) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0x392625) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0xF5A097) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0x392625) }
    ///         Text
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0xF5A097) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0xF5A097) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x231818) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x231818) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x231818) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0xF5A097) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0xF5A097) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

public struct CGAYellowThemePalette: UXThemePalette, Codable, Sendable, Hashable {

    public var name: String { "CGA Yellow" }
    public var group: String { "CGA" }
    public var dark: Bool { true }

#if !os(tvOS)
    public var statusBarColor: UIColor? { UIColor(rgb: 0x201D15) }
#endif
    public var defaultTintColor: UIColor { UIColor(rgb: 0xE4C778) }

#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif

    public var switchThumb: UIColor? { UIColor(rgb: 0xFFFFFF) }
    public var switchON: UIColor? { UIColor(rgb: 0xE4C778) }

    /// Game Library
    ///     Background
    public var gameLibraryBackground: UIColor { UIColor(rgb: 0x201D15) }
    ///     Text
    public var gameLibraryText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Header
    ///         Background
    public var gameLibraryHeaderBackground: UIColor { UIColor(rgb: 0x332E22) }
    ///         Text
    public var gameLibraryHeaderText: UIColor { UIColor(rgb: 0xE4C778) }
    ///     Cell
    ///         Background
    public var gameLibraryCellBackground: UIColor? { UIColor(rgb: 0x332E22) }
    ///         Text
    public var gameLibraryCellText: UIColor { UIColor(rgb: 0xF2F3F7) }

    /// Navigation Bar
    ///     Background
    public var navigationBarBackgroundColor: UIColor? { UIColor(rgb: 0x201D15) }
    ///     Bar button tint
    public var barButtonItemTint: UIColor? { UIColor(rgb: 0xE4C778) }

    /// Settings
    ///     Header
    ///         Background
    public var settingsHeaderBackground: UIColor? { UIColor(rgb: 0x332E22) }
    ///         Text
    public var settingsHeaderText: UIColor? { UIColor(rgb: 0xE4C778) }
    ///     Cell
    ///         Background
    public var settingsCellBackground: UIColor? { UIColor(rgb: 0x332E22) }
    ///         Text
    public var settingsCellText: UIColor? { UIColor(rgb: 0xF2F3F7) }

    /// Menu
    ///     Background
    public var menuBackground: UIColor { UIColor(rgb: 0x201D15) }
    ///     Text
    public var menuText: UIColor { UIColor(rgb: 0xF2F3F7) }
    ///     Divider
    public var menuDivider: UIColor { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
    ///     Icon Tint
    public var menuIconTint: UIColor { UIColor(rgb: 0xE4C778) }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { UIColor(rgb: 0x332E22) }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { UIColor(rgb: 0xE4C778) }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { UIColor(rgb: 0x332E22) }
    ///         Text
    public var menuSectionHeaderText: UIColor { UIColor(rgb: 0xE4C778) }
    ///         Icon
    public var menuSectionHeaderIconTint: UIColor { UIColor(rgb: 0xE4C778) }
    public var uiviewBackground: UIColor? { UIColor(rgb: 0x201D15) }
    public var tableViewBackgroundColor: UIColor? { UIColor(rgb: 0x201D15) }
    public var tabBarBackground: UIColor? { UIColor(rgb: 0x201D15) }
    public var menuHeaderText: UIColor { UIColor(rgb: 0xF2F3F7) }
    public var navigationBarTitleColor: UIColor? { UIColor(rgb: 0xF2F3F7) }
    public var segmentedControlTint: UIColor? { UIColor(rgb: 0xE4C778) }
    public var segmentedControlSelectedTint: UIColor? { UIColor(rgb: 0xE4C778) }
    public var settingsCellTextDetail: UIColor? { UIColor(rgb: 0xB8BDC9) }
    public var settingsSeperator: UIColor? { UIColor(rgb: 0xF2F3F7).withAlphaComponent(0.14) }
}

private extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
