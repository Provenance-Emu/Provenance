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

public enum CGAThemes: String, CaseIterable {
    case blue
    case cyan
    case green
    case magenta
    case red
    case yellow
    case purple
    case rainbow
    
    public var palette: iOSTheme {
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
        }
        return iOSTheme(name: palette.name, palette: palette)
    }
}

public extension UIColor {
    enum CGA {
#if canImport(UIKit)
        public static let blue: UIColor         = #uiColor(0x0000AA)
        public static let blueShadow: UIColor   = #uiColor(0x0000FF)
        
        public static let cyan: UIColor         = #uiColor(0x00AAAA)
        public static let cyanShadow: UIColor   = #uiColor(0x00FFFF)
        
        public static let green: UIColor         = #uiColor(0x00aa00)
        public static let greenShadow: UIColor   = #uiColor(0x00ff00)
        
        public static let magenta: UIColor         = #uiColor(0xaa00aa)
        public static let magentaShadow: UIColor   = #uiColor(0xff00ff)
        
        public static let red: UIColor         = #uiColor(0xaa0000)
        public static let redShadow: UIColor   = #uiColor(0xff0000)
        
        public static let yellow: UIColor         = #uiColor(0xaaaa00)
        public static let yellowShadow: UIColor   = #uiColor(0xffff00)
        
        public static let purple: UIColor         = #uiColor(0xdd33ff)
        public static let purpleShadow: UIColor   = #uiColor(0x6b1383)
#else
        public static let blue: UIColor         = #nsColor(0x0000AA)
        public static let blueShadow: UIColor   = #nsColor(0x0000FF)
        
        public static let cyan: UIColor         = #nsColor(0x00AAAA)
        public static let cyanShadow: UIColor   = #nsColor(0x00FFFF)
        
        public static let green: UIColor         = #nsColor(0x00aa00)
        public static let greenShadow: UIColor   = #nsColor(0x00ff00)
        
        public static let magenta: UIColor         = #nsColor(0xaa00aa)
        public static let magentaShadow: UIColor   = #nsColor(0xff00ff)
        
        public static let red: UIColor         = #nsColor(0xaa0000)
        public static let redShadow: UIColor   = #nsColor(0xff0000)
        
        public static let yellow: UIColor         = #nsColor(0xaaaa00)
        public static let yellowShadow: UIColor   = #nsColor(0xffff00)
        
        public static let purple: UIColor         = #nsColor(0xdd33ff)
        public static let purpleShadow: UIColor   = #nsColor(0x6b1383)
#endif
    }
}

public struct CGABlueThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    
    public var name: String { "CGA Blue" }
    public var group: String { "CGA" }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.blue }
#endif
    public var defaultTintColor: UIColor? { .CGA.blue }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    public var switchThumb: UIColor? { .CGA.blueShadow }
    public var switchON: UIColor? { .CGA.blue }
    
    public var gameLibraryBackground: UIColor { .CGA.blueShadow.brightness(backgroundBrightness) }
    public var gameLibraryCellBackground: UIColor? { .CGA.blueShadow.brightness(0.10) }
    public var gameLibraryText: UIColor { .CGA.blue }
    
    public var gameLibraryHeaderBackground: UIColor { .black }
    public var gameLibraryHeaderText: UIColor { .CGA.blue }
    
    public var navigationBarBackgroundColor: UIColor? { .black }
    public var barButtonItemTint: UIColor? { .CGA.blue }
    
    public var settingsHeaderBackground: UIColor? { .black }
    public var settingsHeaderText: UIColor? { .CGA.blue }
    
    public var settingsCellBackground: UIColor? { .CGA.blueShadow.brightness(0.2) }
    public var settingsCellText: UIColor? { .CGA.blue }
    
    public var menuBackground: UIColor { .CGA.blue.brightness(0.2) }
    public var menuText: UIColor { .CGA.blueShadow }
    public var menuDivider: UIColor { .CGA.blue.brightness(0.4) }
    public var menuIconTint: UIColor { .CGA.blueShadow }
    public var menuHeaderBackground: UIColor { .CGA.blue.brightness(0.3) }
    public var menuHeaderIconTint: UIColor { .CGA.blueShadow }
}

public struct CGACyanThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Cyan" }
    public var group: String { "CGA" }
    public var dark: Bool { false }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.cyan }
#endif
    public var defaultTintColor: UIColor? { .CGA.cyan }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    public var switchThumb: UIColor? { .CGA.cyanShadow }
    public var switchON: UIColor? { .CGA.cyan }
    
    public var gameLibraryBackground: UIColor { .CGA.cyanShadow }
    public var gameLibraryCellBackground: UIColor? { .CGA.cyanShadow.brightness(0.10) }
    public var gameLibraryText: UIColor { .CGA.cyan }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.cyanShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.cyan }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.cyanShadow }
    public var barButtonItemTint: UIColor? { .CGA.cyan }
    
    public var settingsHeaderBackground: UIColor? { .CGA.cyanShadow }
    public var settingsHeaderText: UIColor? { .CGA.cyan }
    
    public var settingsCellBackground: UIColor? { .CGA.cyanShadow }
    public var settingsCellText: UIColor? { .CGA.cyan }
    
    public var menuBackground: UIColor { .CGA.cyan.brightness(0.8) }
    public var menuText: UIColor { .CGA.cyan.brightness(0.2) }
    public var menuDivider: UIColor { .CGA.cyan.brightness(0.6) }
    public var menuIconTint: UIColor { .CGA.cyan.brightness(0.2) }
    public var menuHeaderBackground: UIColor { .CGA.cyan.brightness(0.7) }
    public var menuHeaderIconTint: UIColor { .CGA.cyan.brightness(0.1) }
}

public struct CGAGreenThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    
    var backgroundBrightness: CGFloat = 0.05
    public var name: String { "CGA Green" }
    public var group: String { "CGA" }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.green }
#endif
    public var defaultTintColor: UIColor? { .CGA.green }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    
    public var switchThumb: UIColor? { .CGA.greenShadow }
    public var switchON: UIColor? { .CGA.green }
    
    public var gameLibraryBackground: UIColor { .CGA.greenShadow.brightness(backgroundBrightness) }
    public var gameLibraryText: UIColor { .CGA.green }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.greenShadow }
    public var gameLibraryCellBackground: UIColor? { .CGA.greenShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.green }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.greenShadow }
    public var barButtonItemTint: UIColor? { .CGA.green }
    
    public var settingsHeaderBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
    public var settingsHeaderText: UIColor? { .CGA.green }
    
    public var settingsCellBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
    public var settingsCellText: UIColor? { .CGA.green }
    
    public var menuBackground: UIColor { .CGA.green.brightness(0.2) }
    public var menuText: UIColor { .CGA.greenShadow }
    public var menuDivider: UIColor { .CGA.green.brightness(0.4) }
    public var menuIconTint: UIColor { .CGA.greenShadow }
    public var menuHeaderBackground: UIColor { .CGA.green.brightness(0.3) }
    public var menuHeaderIconTint: UIColor { .CGA.greenShadow }
}

public struct CGAPurpleThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    
    var backgroundBrightness: CGFloat = 0.05
    public var name: String { "CGA Purple" }
    public var group: String { "CGA" }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.purple }
#endif
    public var defaultTintColor: UIColor? { .CGA.purple }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    
    public var switchThumb: UIColor? { .CGA.purpleShadow }
    public var switchON: UIColor? { .CGA.purple }
    
    public var gameLibraryBackground: UIColor { .CGA.purpleShadow.brightness(backgroundBrightness) }
    public var gameLibraryText: UIColor { .CGA.purple }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.purpleShadow }
    public var gameLibraryCellBackground: UIColor? { .CGA.purpleShadow.brightness(0.10) }
    public var gameLibraryHeaderText: UIColor { .CGA.purple }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.purpleShadow }
    public var barButtonItemTint: UIColor? { .CGA.purple }
    
    public var settingsHeaderBackground: UIColor? { .CGA.purpleShadow.brightness(backgroundBrightness) }
    public var settingsHeaderText: UIColor? { .CGA.purple }
    
    public var settingsCellBackground: UIColor? { .CGA.purpleShadow.brightness(backgroundBrightness) }
    public var settingsCellText: UIColor? { .CGA.purple }
    
    public var menuBackground: UIColor { .CGA.purple.brightness(0.2) }
    public var menuText: UIColor { .CGA.purpleShadow }
    public var menuDivider: UIColor { .CGA.purple.brightness(0.4) }
    public var menuIconTint: UIColor { .CGA.purpleShadow }
    public var menuHeaderBackground: UIColor { .CGA.purple.brightness(0.3) }
    public var menuHeaderIconTint: UIColor { .CGA.purpleShadow }
}

public struct CGAMagentaThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Magenta" }
    public var group: String { "CGA" }
    
    var backgroundAlpha: CGFloat { 0.95 }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.magenta }
#endif
    public var defaultTintColor: UIColor? { .CGA.magenta }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    
    public var switchThumb: UIColor? { .CGA.magentaShadow }
    public var switchON: UIColor? { .CGA.magenta }
    
    public var gameLibraryBackground: UIColor { .CGA.magentaShadow }
    public var gameLibraryText: UIColor { .CGA.magenta }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.magentaShadow.withAlphaComponent(backgroundAlpha) }
    public var gameLibraryCellBackground: UIColor? { .CGA.magentaShadow.brightness(0.10) }
    public var gameLibraryHeaderText: UIColor { .CGA.magenta }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.magentaShadow }
    public var barButtonItemTint: UIColor? { .CGA.magenta }
    
    public var settingsHeaderBackground: UIColor? { .CGA.magentaShadow }
    public var settingsHeaderText: UIColor? { .CGA.magenta }
    
    public var settingsCellBackground: UIColor? { .CGA.magentaShadow }
    public var settingsCellText: UIColor? { .CGA.magenta }
    
    public var menuBackground: UIColor { .CGA.magenta.brightness(0.2) }
    public var menuText: UIColor { .CGA.magentaShadow }
    public var menuDivider: UIColor { .CGA.magenta.brightness(0.4) }
    public var menuIconTint: UIColor { .CGA.magentaShadow }
    public var menuHeaderBackground: UIColor { .CGA.magenta.brightness(0.3) }
    public var menuHeaderIconTint: UIColor { .CGA.magentaShadow }
}

public struct CGARedThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Red" }
    public var group: String { "CGA" }
    public var dark: Bool { false }
    
    var backgroundBrightness: CGFloat { 0.90 }
    var backgroundAlpha: CGFloat { 0.95 }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.red }
#endif
    public var defaultTintColor: UIColor? { .CGA.red }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    public var switchThumb: UIColor? { .CGA.redShadow }
    public var switchON: UIColor? { .CGA.red }
    
    public var gameLibraryBackground: UIColor { .CGA.redShadow }
    public var gameLibraryText: UIColor { .CGA.red }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.redShadow.brightness(backgroundBrightness).withAlphaComponent(backgroundAlpha) }
    public var gameLibraryCellBackground: UIColor? { .CGA.redShadow.brightness(0.10) }
    public var gameLibraryHeaderText: UIColor { .CGA.red }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.redShadow }
    public var barButtonItemTint: UIColor? { .CGA.red }
    
    public var settingsHeaderBackground: UIColor? { .CGA.redShadow }
    public var settingsHeaderText: UIColor? { .CGA.red }
    
    public var settingsCellBackground: UIColor? { .CGA.redShadow }
    public var settingsCellText: UIColor? { .CGA.red }
    
    public var menuBackground: UIColor { .CGA.red.brightness(0.8) }
    public var menuText: UIColor { .CGA.red.brightness(0.2) }
    public var menuDivider: UIColor { .CGA.red.brightness(0.6) }
    public var menuIconTint: UIColor { .CGA.red.brightness(0.2) }
    public var menuHeaderBackground: UIColor { .CGA.red.brightness(0.7) }
    public var menuHeaderIconTint: UIColor { .CGA.red.brightness(0.1) }
}

public struct CGAYellowThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    
    public var name: String { "CGA Yellow" }
    public var group: String { "CGA" }
    public var dark: Bool { false }
    var backgroundBrightness: CGFloat = 0.05
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.yellow }
#endif
    public var defaultTintColor: UIColor? { .CGA.yellow }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .light }
#endif
    
    public var switchThumb: UIColor? { .CGA.yellowShadow }
    public var switchON: UIColor? { .CGA.yellow }
    
    public var gameLibraryBackground: UIColor { .CGA.yellowShadow.brightness(backgroundBrightness) }
    public var gameLibraryCellBackground: UIColor? { .CGA.yellowShadow.brightness(0.10) }
    public var gameLibraryText: UIColor { .CGA.yellow }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.yellowShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.yellow }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.yellowShadow }
    public var barButtonItemTint: UIColor? { .CGA.yellow }
    
    public var settingsHeaderBackground: UIColor? { .CGA.yellowShadow }
    public var settingsHeaderText: UIColor? { .CGA.yellow }
    
    public var settingsCellBackground: UIColor? { .CGA.yellowShadow }
    public var settingsCellText: UIColor? { .CGA.yellow }
    
    public var menuBackground: UIColor { .CGA.yellow }
    public var menuText: UIColor { .CGA.yellow.brightness(0.2) }
    public var menuDivider: UIColor { .CGA.yellow.brightness(0.6) }
    public var menuIconTint: UIColor { .CGA.yellow.brightness(0.2) }
    public var menuHeaderBackground: UIColor { .CGA.yellow.brightness(0.7) }
    public var menuHeaderIconTint: UIColor { .CGA.yellow.brightness(0.1) }
}

public struct CGARainbowThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    
    public var name: String { "CGA Rainbow" }
    public var group: String { "CGA" }
    
#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.blue }
#endif
    public var defaultTintColor: UIColor? { .CGA.cyan }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { .dark }
#endif
    
    public var switchThumb: UIColor? { .CGA.yellowShadow }
    public var switchON: UIColor? { .CGA.green }
    
    public var gameLibraryBackground: UIColor { .CGA.blueShadow.brightness(0.1) }
    public var gameLibraryText: UIColor { .CGA.yellow }
    
    public var gameLibraryHeaderBackground: UIColor { .CGA.purpleShadow }
    public var gameLibraryCellBackground: UIColor? { .CGA.redShadow.brightness(0.2) }
    public var gameLibraryHeaderText: UIColor { .CGA.magenta }
    
    public var navigationBarBackgroundColor: UIColor? { .CGA.redShadow }
    public var barButtonItemTint: UIColor? { .CGA.cyan }
    
    public var settingsHeaderBackground: UIColor? { .CGA.greenShadow.brightness(0.1) }
    public var settingsHeaderText: UIColor? { .CGA.yellow }
    
    public var settingsCellBackground: UIColor? { .CGA.magentaShadow.brightness(0.2) }
    public var settingsCellText: UIColor? { .CGA.cyan }
    
    public var menuBackground: UIColor { .CGA.purple.brightness(0.2) }
    public var menuText: UIColor { .CGA.yellowShadow }
    public var menuDivider: UIColor { .CGA.red.brightness(0.4) }
    public var menuIconTint: UIColor { .CGA.greenShadow }
    public var menuHeaderBackground: UIColor { .CGA.blue.brightness(0.3) }
    public var menuHeaderIconTint: UIColor { .CGA.cyanShadow }
}
