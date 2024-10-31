//
//  CGAGreenThemePalette.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/24/24.
//

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#elseif canImport(AppKit)
import AppKit
#endif
import HexColors

// public struct CGAGreenThemePalette: UXThemePalette, Codable, Sendable, Hashable {

//     public var name: String { "CGA Green" }
//     public var group: String { "CGA" }

// #if !os(tvOS)
//     public var statusBarColor: UIColor { .CGA.green }
// #endif
//     public var defaultTintColor: UIColor? { .CGA.green }

// #if canImport(UIKit)
//     public var keyboardAppearance: UIKeyboardAppearance { .dark }
// #endif

//     /// Switches
//     public var switchThumb: UIColor? { .CGA.greenShadow }
//     public var switchON: UIColor? { .CGA.green }

//     /// Game Library
//     ///     Background
//     public var gameLibraryBackground: UIColor { .CGA.greenShadow.brightness(0.10) }
//     ///     Text
//     public var gameLibraryText: UIColor { .CGA.green.brightness(1.0) }
//     ///     Cell
//     ///         Background
//     public var gameLibraryCellBackground: UIColor { .CGA.greenShadow.brightness(0.20) }
//     ///         Text
//     public var gameLibraryCellText: UIColor { .CGA.green.brightness(1.0) }
//     ///     Header
//     ///         Background
//     public var gameLibraryHeaderBackground: UIColor { .CGA.green.withAlphaComponent(0.20) }
//     ///         Text
//     public var gameLibraryHeaderText: UIColor { .CGA.green }

//     /// Navigation Bar
//     ///     Background Color
//     public var navigationBarBackgroundColor: UIColor? { .CGA.greenShadow }
//     ///     Item Tint
//     public var barButtonItemTint: UIColor? { .CGA.green }

//     /// Settings
//     ///     Header Background
//     public var settingsHeaderBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
//     ///     Header Text
//     public var settingsHeaderText: UIColor? { .CGA.green }
//     ///     Cell Background
//     public var settingsCellBackground: UIColor? { .CGA.greenShadow.brightness(backgroundBrightness) }
//     ///     Cell Text
//     public var settingsCellText: UIColor? { .CGA.green }

//     ///  Menu
//     ///     Background
//     public var menuBackground: UIColor { .CGA.green.brightness(0.2) }
//     ///     Text
//     public var menuText: UIColor { .CGA.greenShadow }
//     ///     Divider
//     public var menuDivider: UIColor { .CGA.green.brightness(0.4) }
//     ///     Icon Tint
//     public var menuIconTint: UIColor { .CGA.greenShadow }
//     ///     Header
//     ///         Background
//     public var menuHeaderBackground: UIColor  { .CGA.green.brightness(0.3) }
//     ///         Tint
//     public var menuHeaderIconTint: UIColor { .CGA.greenShadow }
//     ///     Section Header
//     ///         Background
//     public var menuSectionHeaderBackground: UIColor  { .CGA.green.brightness(0.3) }
//     ///         Tint
//     public var menuSectionHeaderIconTint: UIColor { .CGA.green }
// }
