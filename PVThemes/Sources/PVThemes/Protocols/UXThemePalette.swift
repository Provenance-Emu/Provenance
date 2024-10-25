//
//  UXThemePalette.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 7/23/24.
//

import Foundation

#if canImport(UIKit)
import UIKit.UIColor
#else
import AppKit
public typealias UIColor = NSColor
#endif

public protocol PaletteProvider {
    var palette: any UXThemePalette { get }
}

public protocol UXThemePalette: Codable, Equatable, Hashable, Sendable  {

    var name: String { get }
    var group: String? { get }

    var dark: Bool { get }
    
    var uiviewBackground: UIColor? { get }

#if !os(tvOS)
    var statusBarColor: UIColor? { get }
#endif
    /// Game Library
    ///     Background
    var gameLibraryBackground: UIColor { get }
    ///     Text
    var gameLibraryText: UIColor { get }
    ///     Cell
    ///         Background
    var gameLibraryCellBackground: UIColor? { get }
    ///         Text
    var gameLibraryCellText: UIColor { get }
    ///     Header
    ///         Background
    var gameLibraryHeaderBackground: UIColor { get }
    ///         Text
    var gameLibraryHeaderText: UIColor { get }


    /// General
    ///     Bar Buttom Item Tint
    var barButtonItemTint: UIColor? { get }
    ///     Tint
    ///         Optional - Defaults to nil (OS chooses)
    var defaultTintColor: UIColor? { get }

#if canImport(UIKit)
    var keyboardAppearance: UIKeyboardAppearance { get }
#endif

    /// Settings
    ///     Header
    ///         Background
    var settingsHeaderBackground: UIColor? { get }
    ///         Text
    var settingsHeaderText: UIColor? { get }
    ///     Cells
    ///         Background
    var settingsCellBackground: UIColor? { get }
    ///         Text
    var settingsCellText: UIColor? { get }
    ///         Detail Text
    var settingsCellTextDetail: UIColor? { get }
    
    /// TableView
    ///     Background
    var tableViewBackgroundColor: UIColor? { get }

    /// UISwitch
    ///     On
    var switchON: UIColor? { get }
    ///     Thumb
    var switchThumb: UIColor? { get }
    
    /// Segmented Control
    ///     Tint
    var segmentedControlTint: UIColor? { get }
    ///     Selected Tint
    var segmentedControlSelectedTint: UIColor? { get }
    
    /// Navigation Bar
    ///     Background
    var navigationBarBackgroundColor: UIColor? { get }
    ///     Title
    var navigationBarTitleColor: UIColor? { get }
   
    /// Tab bar
    ///     Background
    var tabBarBackground: UIColor? { get }
    
    /// Settings
    ///     Seperator color
    var settingsSeperator: UIColor? { get }
    
    /// Side Menu
    ///     Background
    var menuBackground: UIColor { get }
    ///     Text
    var menuText: UIColor { get }
    ///     Divider
    var menuDivider: UIColor { get }
    ///     Icon Tint
    var menuIconTint: UIColor { get }
    ///     Header
    ///         Background
    var menuHeaderBackground: UIColor { get }
    ///         Text
    var menuHeaderText: UIColor { get }
    ///         Icon Tint
    var menuHeaderIconTint: UIColor { get }
    ///     Section Header
    ///         Background
    var menuSectionHeaderBackground: UIColor { get }
    ///         Text
    var menuSectionHeaderText: UIColor { get }
    ///         Icon
    var menuSectionHeaderIconTint: UIColor { get }
}

// MARK: - Default implimentnations

public extension UXThemePalette {
    var group: String? { nil }
#if canImport(UIKit)
    var dark: Bool { keyboardAppearance == .dark }
    #else
    var dark: Bool { true }
    #endif
}

public extension UXThemePalette {
#if canImport(UIKit)
    var keyboardAppearance: UIKeyboardAppearance { .default }
#endif
}

#if !os(tvOS)
public extension UXThemePalette {
    var statusBarColor: UIColor? { nil }
}
#endif

public extension UXThemePalette {
    // Default to default tint (which defaults to nil)
    var barButtonItemTint: UIColor? { defaultTintColor }
    var alertViewTintColor: UIColor? { defaultTintColor }
    var switchON: UIColor? { defaultTintColor }
}

public extension UXThemePalette {
    /// Defaults to NIL will use iOS defaults
    var defaultTintColor: UIColor? { nil }
    var switchThumb: UIColor? { nil }
    var uiviewBackground: UIColor? { nil }
}


/// Navigation
public extension UXThemePalette {
    /// Navbar Title Text
    var navigationBarTitleColor: UIColor? { nil }
    /// Navbar Background
    var navigationBarBackgroundColor: UIColor? { UIColor.systemBackground }
}

/// TableView
public extension UXThemePalette {
    /// TableView TableView
    var tableViewBackgroundColor: UIColor? { nil }
}

/// Game Library
public extension UXThemePalette {
    /// Library Header Background
    var gameLibraryHeaderBackground: UIColor { UIColor.secondarySystemBackground }
    var gameLibraryHeaderText: UIColor { .label }

    var gameLibraryCellBackground: UIColor? { nil }
    var gameLibraryCellText: UIColor { gameLibraryText }

    var gameLibraryBackground: UIColor { .black }
    var gameLibraryText: UIColor { .white }
}

/// Menu
public extension UXThemePalette {
    var menuBackground: UIColor { .systemBackground }
    var menuText: UIColor { .Provenance.blue }
    var menuDivider: UIColor { .Provenance.blue }
    var menuIconTint: UIColor { .Provenance.blue }
    var menuHeaderBackground: UIColor { .secondarySystemBackground }
    var menuHeaderText: UIColor { settingsCellText ?? .Provenance.blue }
    var menuHeaderIconTint: UIColor { .Provenance.blue }
    var menuSectionHeaderBackground: UIColor { menuHeaderBackground }
    var menuSectionHeaderText: UIColor { menuHeaderText }
    var menuSectionHeaderIconTint: UIColor { menuHeaderIconTint }
}

/// Tabs
public extension UXThemePalette {
    var tabBarBackground: UIColor? { self.uiviewBackground }
}

/// Segmented Control
public extension UXThemePalette {
    var segmentedControlTint: UIColor? { .Provenance.blue  }
    var segmentedControlSelectedTint: UIColor? {.Provenance.blue.saturation(0.2) }
}

/// Seperator color
public extension UXThemePalette {
    var settingsSeperator: UIColor? { self.settingsCellText }
}

/// Settings
public extension UXThemePalette {
    /// Defaults to NIL will use iOS defaults
    var settingsCellBackground: UIColor? { nil }
    var settingsCellText: UIColor? { nil }
    var settingsCellTextDetail: UIColor? { nil }

    var settingsHeaderBackground: UIColor? { nil }
    var settingsHeaderText: UIColor? { nil }
}

public extension UXThemePalette {
    var backgroundBrightness: CGFloat { 0.07 }
}

public extension Hashable where Self: UXThemePalette {
    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

public extension Equatable where Self: UXThemePalette {
    // MARK: Equatable
#if canImport(UIKit)
    static func == (lhs: Self, rhs: Self) -> Bool {
        #if !os(tvOS)
        let stausBarColor: Bool = lhs.statusBarColor == rhs.statusBarColor
        #else
        let stausBarColor: Bool = true
        #endif
        
        return lhs.name == rhs.name &&
        stausBarColor &&
        lhs.gameLibraryBackground == rhs.gameLibraryBackground &&
        lhs.gameLibraryText == rhs.gameLibraryText &&
        lhs.gameLibraryHeaderBackground == rhs.gameLibraryHeaderBackground &&
        lhs.gameLibraryHeaderText == rhs.gameLibraryHeaderText &&
        lhs.defaultTintColor == rhs.defaultTintColor &&
        lhs.keyboardAppearance == rhs.keyboardAppearance &&
        lhs.barButtonItemTint == rhs.barButtonItemTint &&
        lhs.navigationBarBackgroundColor == rhs.navigationBarBackgroundColor &&
        lhs.switchON == rhs.switchON &&
        lhs.switchThumb == rhs.switchThumb &&
        lhs.settingsHeaderBackground == rhs.settingsHeaderBackground &&
        lhs.settingsHeaderText == rhs.settingsHeaderText &&
        lhs.settingsCellBackground == rhs.settingsCellBackground &&
        lhs.settingsCellText == rhs.settingsCellText
    }
#else
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name &&
        lhs.statusBarColor == rhs.statusBarColor &&
        lhs.gameLibraryBackground == rhs.gameLibraryBackground &&
        lhs.gameLibraryText == rhs.gameLibraryText &&
        lhs.gameLibraryHeaderBackground == rhs.gameLibraryHeaderBackground &&
        lhs.gameLibraryHeaderText == rhs.gameLibraryHeaderText &&
        lhs.defaultTintColor == rhs.defaultTintColor &&
        lhs.barButtonItemTint == rhs.barButtonItemTint &&
        lhs.navigationBarBackgroundColor == rhs.navigationBarBackgroundColor &&
        lhs.switchON == rhs.switchON &&
        lhs.switchThumb == rhs.switchThumb &&
        lhs.settingsHeaderBackground == rhs.settingsHeaderBackground &&
        lhs.settingsHeaderText == rhs.settingsHeaderText &&
        lhs.settingsCellBackground == rhs.settingsCellBackground &&
        lhs.settingsCellText == rhs.settingsCellText
    }
#endif
}
