//
//  LightTheme.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#endif

public
struct LightThemePalette: UXThemePalette {
    
    public var name: String = "Provenance Light"
    public var group: String { "Provenance" }
    public var dark: Bool { false }

    enum Colors {
        static let white9alpha6 = UIColor(white: 0.9, alpha: 0.6)
    }

    public var defaultTintColor: UIColor? { .Provenance.blue } // iOS Blue

    public var gameLibraryBackground: UIColor { .white }
    public var gameLibraryCellBackground: UIColor? { .white }
    public var gameLibraryText: UIColor { .black }

    public var gameLibraryHeaderBackground: UIColor { Colors.white9alpha6 }
    public var gameLibraryHeaderText: UIColor { .darkGray }

    public var navigationBarBackgroundColor: UIColor? { .grey.g1C }
    public var statusBarColor: UIColor { .grey.g1C }

    public var settingsCellBackground: UIColor? { .white }
    public var settingsCellText: UIColor? { .black }
    public var settingsCellTextDetail: UIColor? { .gray }
    
    public var barButtonItemTint: UIColor? { .Provenance.blue }
    
    // Switch
    public var switchON: UIColor { .Provenance.blue }
    public var switchThumb: UIColor { .Provenance.blue.brightness(0.95) }
    
    /// Side Menu
    public var menuBackground: UIColor { .white }
    public var menuText: UIColor { .tintColor }
    public var menuDivider: UIColor { .lightGray }
    public var menuIconTint: UIColor { .tintColor }
    public var menuHeaderBackground: UIColor { .white }
    public var menuHeaderIconTint: UIColor { .Provenance.blue }
}
