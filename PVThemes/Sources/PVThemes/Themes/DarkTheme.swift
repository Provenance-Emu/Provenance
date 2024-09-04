//
//  DarkTheme.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import HexColors

public enum ProvenanceThemes: CaseIterable {
    case `default`
    case dark
    case light

    public var palette: iOSTheme {
        let palette: any UXThemePalette
        switch self {
        case .dark, .default:
            palette = DarkThemePalette()
        case .light:
            palette = LightThemePalette()
        }
        return iOSTheme(name: palette.name, palette: palette)
    }
}

public
struct DarkThemePalette: UXThemePalette {

    enum Colors {
#if canImport(UIKit)
        static let lightBlue: UIColor   = #uiColor(0x18A9F7)
        static let blueishGrey: UIColor = #uiColor(0x848489)
        #else
        static let lightBlue: UIColor   = #nsColor(0x18A9F7)
        static let blueishGrey: UIColor = #nsColor(0x848489)
        #endif
    }

    public var name: String { "Provenance Dark" }
    public var group: String { "Provenance" }

#if !os(tvOS)
    public var statusBarColor: UIColor { .grey.g1C }
#endif
    public var defaultTintColor: UIColor? { Colors.blueishGrey }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance = .dark
#endif
    
    public var switchON: UIColor? { Colors.lightBlue }
    public var switchThumb: UIColor? { .grey.gEEE }

    public var gameLibraryBackground: UIColor { .black }
    public var gameLibraryText: UIColor { .grey.g6F}

    public var gameLibraryHeaderBackground: UIColor { UIColor.black }
    public var gameLibraryHeaderText: UIColor { .grey.g333}

    public var barButtonItemTint: UIColor? { Colors.lightBlue }
    public var navigationBarBackgroundColor: UIColor? { .grey.g1C }

    public var settingsHeaderBackground: UIColor? { .black }
    public var settingsHeaderText: UIColor? { .grey.middleGrey }

    public var settingsCellBackground: UIColor? { .grey.g29 }
    public var settingsCellText: UIColor? { .grey.middleGrey  }
}

public let ProvenanceDarkTheme: iOSTheme = .init(name: "Provenance Dark", palette: DarkThemePalette())
