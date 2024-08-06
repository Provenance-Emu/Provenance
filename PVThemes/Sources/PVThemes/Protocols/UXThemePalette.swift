//
//  UXThemePalette.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 7/23/24.
//

import Foundation

import UIKit.UIColor

public protocol UXThemePalette: Codable, Equatable, Hashable, Sendable  {
    var name: String { get }
    var group: String? { get }

    var dark: Bool { get }

#if !os(tvOS)
    var statusBarColor: UIColor? { get }
#endif
    // Mandatory
    var gameLibraryBackground: UIColor { get }
    var gameLibraryText: UIColor { get }

    var gameLibraryHeaderBackground: UIColor { get }
    var gameLibraryHeaderText: UIColor { get }

    // Optional - Defaults to nil (OS chooses)
    var defaultTintColor: UIColor? { get }

    var barButtonItemTint: UIColor? { get }

    var keyboardAppearance: UIKeyboardAppearance { get }

    var navigationBarBackgroundColor: UIColor? { get }

    var settingsHeaderBackground: UIColor? { get }
    var settingsHeaderText: UIColor? { get }

    var settingsCellBackground: UIColor? { get }
    var settingsCellText: UIColor? { get }
    var settingsCellTextDetail: UIColor? { get }

    var switchON: UIColor? { get }
    var switchThumb: UIColor? { get }
}

// MARK: - Default implimentnations

public extension UXThemePalette {
    var group: String? { nil }
    var dark: Bool { keyboardAppearance == .dark }
}

public extension UXThemePalette {
    var keyboardAppearance: UIKeyboardAppearance { .default }
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
    var navigationBarBackgroundColor: UIColor? { nil }
}

public extension UXThemePalette {
    var gameLibraryBackground: UIColor { .black }
    var gameLibraryText: UIColor { .white }
    var gameLibraryHeaderBackground: UIColor { .black }
    var gameLibraryHeaderText: UIColor { .white }
}

public extension UXThemePalette {
    /// Defaults to NIL will use iOS defaults
    var settingsCellBackground: UIColor? { nil }
    var settingsCellText: UIColor? { nil }
    var settingsCellTextDetail: UIColor? { nil }

    var settingsHeaderBackground: UIColor? { nil }
    var settingsHeaderText: UIColor? { nil }
}

public extension Hashable where Self: UXThemePalette {
    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

public extension Equatable where Self: UXThemePalette {
    // MARK: Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name &&
        lhs.statusBarColor == rhs.statusBarColor &&
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
}
