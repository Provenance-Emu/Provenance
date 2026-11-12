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
        static let accent = UIColor(red: 0, green: 0.36, blue: 0.70, alpha: 1)
        static let white9alpha6 = UIColor(white: 0.9, alpha: 0.6)
    }

    public var defaultTintColor: UIColor { Colors.accent }

    public var gameLibraryBackground: UIColor { .white }
    public var gameLibraryCellBackground: UIColor? { .white }
    public var gameLibraryText: UIColor { .black }

    public var gameLibraryHeaderBackground: UIColor { Colors.white9alpha6 }
    public var gameLibraryHeaderText: UIColor { .darkGray }

    public var navigationBarBackgroundColor: UIColor? { .white }
    #if !os(tvOS)
    public var statusBarColor: UIColor? { .white }
    #endif
    public var navigationBarTitleColor: UIColor? { .black }

    public var settingsCellBackground: UIColor? { .white }
    public var settingsCellText: UIColor? { .black }
    public var settingsCellTextDetail: UIColor? { .darkGray }
    
    public var barButtonItemTint: UIColor? { defaultTintColor }
    
    // Switch
    public var switchON: UIColor { defaultTintColor }
    public var switchThumb: UIColor { .white }
    
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
    public var menuHeaderIconTint: UIColor { defaultTintColor }
    ///     Section Header
    ///         Background
    public var menuSectionHeaderBackground: UIColor { .lightGray }
    ///         Tint
    public var menuSectionHeaderIconTint: UIColor { defaultTintColor }
}
