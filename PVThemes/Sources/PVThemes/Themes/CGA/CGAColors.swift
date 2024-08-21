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
#endif
import HexColors

public enum CGAThemes: CaseIterable {
    case blue
    case cyan
    case green
    case magenta
    case red
    case yellow

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
        }
        return iOSTheme(name: palette.name, palette: palette)
    }
}

public extension UIColor {
    enum CGA {
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
    }
}

public struct CGABlueThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Blue" }
    public var group: String { "CGA" }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.blue }
#endif
    public var defaultTintColor: UIColor? { .CGA.blue }

    public var keyboardAppearance: UIKeyboardAppearance { .dark }

    public var switchThumb: UIColor? { .CGA.blueShadow }
    public var switchON: UIColor? { .CGA.blue }

    public var gameLibraryBackground: UIColor { .CGA.blueShadow }
    public var gameLibraryText: UIColor { .CGA.blue }

    public var gameLibraryHeaderBackground: UIColor { .CGA.blueShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.blue }

    public var navigationBarBackgroundColor: UIColor? { .CGA.blueShadow }
    public var barButtonItemTint: UIColor? { .CGA.blue }

    public var settingsHeaderBackground: UIColor? { .CGA.blueShadow }
    public var settingsHeaderText: UIColor? { .CGA.blue }

    public var settingsCellBackground: UIColor? { .CGA.blueShadow }
    public var settingsCellText: UIColor? { .CGA.blue }
}

public struct CGACyanThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Cyan" }
    public var group: String { "CGA" }
    public var dark: Bool { false }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.cyan }
#endif
    public var defaultTintColor: UIColor? { .CGA.cyan }

    public var keyboardAppearance: UIKeyboardAppearance { .light }

    public var switchThumb: UIColor? { .CGA.cyanShadow }
    public var switchON: UIColor? { .CGA.cyan }

    public var gameLibraryBackground: UIColor { .CGA.cyanShadow }
    public var gameLibraryText: UIColor { .CGA.cyan }

    public var gameLibraryHeaderBackground: UIColor { .CGA.cyanShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.cyan }

    public var navigationBarBackgroundColor: UIColor? { .CGA.cyanShadow }
    public var barButtonItemTint: UIColor? { .CGA.cyan }

    public var settingsHeaderBackground: UIColor? { .CGA.cyanShadow }
    public var settingsHeaderText: UIColor? { .CGA.cyan }

    public var settingsCellBackground: UIColor? { .CGA.cyanShadow }
    public var settingsCellText: UIColor? { .CGA.cyan }
}

public struct CGAGreenThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Green" }
    public var group: String { "CGA" }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.green }
#endif
    public var defaultTintColor: UIColor? { .CGA.green }

    public var keyboardAppearance: UIKeyboardAppearance { .dark }

    public var switchThumb: UIColor? { .CGA.greenShadow }
    public var switchON: UIColor? { .CGA.green }

    public var gameLibraryBackground: UIColor { .CGA.greenShadow }
    public var gameLibraryText: UIColor { .CGA.green }

    public var gameLibraryHeaderBackground: UIColor { .CGA.greenShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.green }

    public var navigationBarBackgroundColor: UIColor? { .CGA.greenShadow }
    public var barButtonItemTint: UIColor? { .CGA.green }

    public var settingsHeaderBackground: UIColor? { .CGA.greenShadow }
    public var settingsHeaderText: UIColor? { .CGA.green }

    public var settingsCellBackground: UIColor? { .CGA.greenShadow }
    public var settingsCellText: UIColor? { .CGA.green }
}

public struct CGAMagentaThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Magenta" }
    public var group: String { "CGA" }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.magenta }
#endif
    public var defaultTintColor: UIColor? { .CGA.magenta }

    public var keyboardAppearance: UIKeyboardAppearance { .dark }

    public var switchThumb: UIColor? { .CGA.magentaShadow }
    public var switchON: UIColor? { .CGA.magenta }

    public var gameLibraryBackground: UIColor { .CGA.magentaShadow }
    public var gameLibraryText: UIColor { .CGA.magenta }

    public var gameLibraryHeaderBackground: UIColor { .CGA.magentaShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.magenta }

    public var navigationBarBackgroundColor: UIColor? { .CGA.magentaShadow }
    public var barButtonItemTint: UIColor? { .CGA.magenta }

    public var settingsHeaderBackground: UIColor? { .CGA.magentaShadow }
    public var settingsHeaderText: UIColor? { .CGA.magenta }

    public var settingsCellBackground: UIColor? { .CGA.magentaShadow }
    public var settingsCellText: UIColor? { .CGA.magenta }
}

public struct CGARedThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Red" }
    public var group: String { "CGA" }
    public var dark: Bool { false }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.red }
#endif
    public var defaultTintColor: UIColor? { .CGA.red }

    public var keyboardAppearance: UIKeyboardAppearance { .light }

    public var switchThumb: UIColor? { .CGA.redShadow }
    public var switchON: UIColor? { .CGA.red }

    public var gameLibraryBackground: UIColor { .CGA.redShadow }
    public var gameLibraryText: UIColor { .CGA.red }

    public var gameLibraryHeaderBackground: UIColor { .CGA.redShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.red }

    public var navigationBarBackgroundColor: UIColor? { .CGA.redShadow }
    public var barButtonItemTint: UIColor? { .CGA.red }

    public var settingsHeaderBackground: UIColor? { .CGA.redShadow }
    public var settingsHeaderText: UIColor? { .CGA.red }

    public var settingsCellBackground: UIColor? { .CGA.redShadow }
    public var settingsCellText: UIColor? { .CGA.red }
}

public struct CGAYellowThemePalette: UXThemePalette, Codable, Sendable, Hashable {
    public var name: String { "CGA Yellow" }
    public var group: String { "CGA" }
    public var dark: Bool { false }

#if !os(tvOS)
    public var statusBarColor: UIColor { .CGA.yellow }
#endif
    public var defaultTintColor: UIColor? { .CGA.yellow }

    public var keyboardAppearance: UIKeyboardAppearance { .light }

    public var switchThumb: UIColor? { .CGA.yellowShadow }
    public var switchON: UIColor? { .CGA.yellow }

    public var gameLibraryBackground: UIColor { .CGA.yellowShadow }
    public var gameLibraryText: UIColor { .CGA.yellow }

    public var gameLibraryHeaderBackground: UIColor { .CGA.yellowShadow }
    public var gameLibraryHeaderText: UIColor { .CGA.yellow }

    public var navigationBarBackgroundColor: UIColor? { .CGA.yellowShadow }
    public var barButtonItemTint: UIColor? { .CGA.yellow }

    public var settingsHeaderBackground: UIColor? { .CGA.yellowShadow }
    public var settingsHeaderText: UIColor? { .CGA.yellow }

    public var settingsCellBackground: UIColor? { .CGA.yellowShadow }
    public var settingsCellText: UIColor? { .CGA.yellow }
}
