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
    // Mandatory
    var gameLibraryBackground: UIColor { get }
    var gameLibraryCellBackground: UIColor? { get }
    var gameLibraryCellText: UIColor { get }
    var gameLibraryText: UIColor { get }

    var gameLibraryHeaderBackground: UIColor { get }
    var gameLibraryHeaderText: UIColor { get }

    // Optional - Defaults to nil (OS chooses)
    var defaultTintColor: UIColor? { get }

    var barButtonItemTint: UIColor? { get }
#if canImport(UIKit)
    var keyboardAppearance: UIKeyboardAppearance { get }
#endif

    /// Settings
    /// Settings > Header
    var settingsHeaderBackground: UIColor? { get }
    var settingsHeaderText: UIColor? { get }

    /// Settings > Cells
    var settingsCellBackground: UIColor? { get }
    var settingsCellText: UIColor? { get }
    var settingsCellTextDetail: UIColor? { get }
    
    /// TableView
    var tableViewBackgroundColor: UIColor? { get }

    /// UISwitch
    var switchON: UIColor? { get }
    var switchThumb: UIColor? { get }
    
    /// Segmented Control
    var segmentedControlTint: UIColor? { get }
    var segmentedControlSelectedTint: UIColor? { get }
    
    // Navigation
    var navigationBarTitleColor: UIColor? { get }
    var navigationBarBackgroundColor: UIColor? { get }

    // Tabs
    var tabBarBackground: UIColor? { get }
    
    // Seperator color
    var settingsSeperator: UIColor? { get }
    
    /// Side Menu
    var menuBackground: UIColor { get }
    var menuText: UIColor { get }
    var menuDivider: UIColor { get }
    var menuIconTint: UIColor { get }
    var menuHeaderBackground: UIColor { get }
    var menuHeaderText: UIColor { get }
    var menuHeaderIconTint: UIColor { get }
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
