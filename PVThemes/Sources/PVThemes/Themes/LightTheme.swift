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

    public var defaultTintColor: UIColor { .Provenance.blue } // iOS Blue

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
    ///     Background
    public var menuBackground: UIColor { .white }
    ///     Text
    public var menuText: UIColor { .tintColor }
    ///     Divider
    public var menuDivider: UIColor { .lightGray }
    ///     Icon Tint
    public var menuIconTint: UIColor { .tintColor }
    ///     Header
    ///         Background
    public var menuHeaderBackground: UIColor { .white }
    ///         Icon Tint
    public var menuHeaderIconTint: UIColor { .Provenance.blue }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { .lightGray }
    ///         Tint
    public var menuSectionHeaderIconTint: UIColor { .Provenance.blue }
}
