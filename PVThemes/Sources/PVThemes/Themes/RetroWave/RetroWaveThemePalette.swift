//
//  RetroWaveThemePalette.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 4/1/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public struct RetroWaveThemePalette: UXThemePalette {
    
    // MARK: - Retrowave Colors
    enum Colors {
        #if canImport(UIKit)
        static let retroPink = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0)
        static let retroPurple = UIColor(red: 0.53, green: 0.11, blue: 0.91, alpha: 1.0)
        static let retroBlue = UIColor(red: 0.0, green: 0.75, blue: 0.95, alpha: 1.0)
        static let retroDarkBlue = UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1.0)
        static let retroBlack = UIColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
        #else
        static let retroPink = NSColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0)
        static let retroPurple = NSColor(red: 0.53, green: 0.11, blue: 0.91, alpha: 1.0)
        static let retroBlue = NSColor(red: 0.0, green: 0.75, blue: 0.95, alpha: 1.0)
        static let retroDarkBlue = NSColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1.0)
        static let retroBlack = NSColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
        #endif
    }
    
    // MARK: - Theme Properties
    public var name: String { "RetroWave" }
    public var group: String? { "Provenance" }
    
    // Always use dark mode for retrowave theme
    #if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance = .dark
    #endif
    
    // MARK: - Basic UI Elements
    public var defaultTintColor: UIColor { Colors.retroPink }
    public var uiviewBackground: UIColor? { Colors.retroBlack }
    
    #if !os(tvOS)
    public var statusBarColor: UIColor? { Colors.retroBlack }
    #endif
    
    // MARK: - Game Library
    public var gameLibraryBackground: UIColor { Colors.retroBlack }
    public var gameLibraryText: UIColor { Colors.retroPink }
    public var gameLibraryCellBackground: UIColor? { Colors.retroDarkBlue.withAlphaComponent(0.7) }
    public var gameLibraryCellText: UIColor { .white }
    public var gameLibraryHeaderBackground: UIColor { Colors.retroDarkBlue }
    public var gameLibraryHeaderText: UIColor { Colors.retroBlue }
    
    // MARK: - Navigation
    public var navigationBarBackgroundColor: UIColor? { Colors.retroBlack }
    public var navigationBarTitleColor: UIColor? { Colors.retroPink }
    
    // MARK: - Tab Bar
    public var tabBarBackground: UIColor? { Colors.retroBlack }
    
    // MARK: - Settings
    public var settingsHeaderBackground: UIColor? { Colors.retroDarkBlue }
    public var settingsHeaderText: UIColor? { Colors.retroBlue }
    public var settingsCellBackground: UIColor? { Colors.retroBlack }
    public var settingsCellText: UIColor? { .white }
    public var settingsCellTextDetail: UIColor? { Colors.retroPink.withAlphaComponent(0.8) }
    public var settingsSeperator: UIColor? { Colors.retroPurple.withAlphaComponent(0.3) }
    
    // MARK: - Table View
    public var tableViewBackgroundColor: UIColor? { Colors.retroBlack }
    
    // MARK: - Controls
    public var switchON: UIColor? { Colors.retroPink }
    public var switchThumb: UIColor? { .white }
    public var segmentedControlTint: UIColor? { Colors.retroBlue }
    public var segmentedControlSelectedTint: UIColor? { Colors.retroPink }
    
    // MARK: - Menu
    public var menuBackground: UIColor { Colors.retroBlack }
    public var menuText: UIColor { .white }
    public var menuDivider: UIColor { Colors.retroPurple.withAlphaComponent(0.3) }
    public var menuIconTint: UIColor { Colors.retroBlue }
    public var menuHeaderBackground: UIColor { Colors.retroDarkBlue }
    public var menuHeaderText: UIColor { Colors.retroPink }
    public var menuHeaderIconTint: UIColor { Colors.retroPink }
    public var menuSectionHeaderBackground: UIColor { Colors.retroDarkBlue.withAlphaComponent(0.5) }
    public var menuSectionHeaderText: UIColor { Colors.retroBlue }
    public var menuSectionHeaderIconTint: UIColor { Colors.retroBlue }
    
    // MARK: - Initializer
    public init() {}
}
