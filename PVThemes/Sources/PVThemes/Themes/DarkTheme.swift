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
    public var defaultTintColor: UIColor { .Provenance.blue }
    
#if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance = .dark
#endif
    
    public var switchON: UIColor? { Colors.lightBlue }
    public var switchThumb: UIColor? { .grey.gEEE }

    public var gameLibraryBackground: UIColor { .black }
    public var gameLibraryText: UIColor { .Provenance.blue }

    public var gameLibraryHeaderBackground: UIColor { UIColor.black }
    public var gameLibraryHeaderText: UIColor { .Provenance.blue }

    public var barButtonItemTint: UIColor? { Colors.lightBlue }
    public var navigationBarBackgroundColor: UIColor? { .grey.g1C }

    public var settingsHeaderBackground: UIColor? { .black }
    public var settingsHeaderText: UIColor? { .grey.middleGrey }

    public var settingsCellBackground: UIColor? { .grey.g29 }
    public var settingsCellText: UIColor? { .grey.middleGrey  }
}
