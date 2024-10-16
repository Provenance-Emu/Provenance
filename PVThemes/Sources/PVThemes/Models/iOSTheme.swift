//
//  iOSTheme.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 7/22/24.
//

import Foundation
import SwiftMacros

public struct iOSTheme: UXThemePalette, Codable, Sendable, Hashable, Observable {

    public let name: String

    public let palette: any UXThemePalette

    public init(name: String, palette: any UXThemePalette) {
        self.name = name
        self.palette = palette
    }

    // Mandatory
    public var gameLibraryBackground: UIColor { palette.gameLibraryBackground }
    public var gameLibraryText: UIColor { palette.gameLibraryText }

    public var gameLibraryHeaderBackground: UIColor { palette.gameLibraryHeaderBackground }
    public var gameLibraryHeaderText: UIColor { palette.gameLibraryHeaderText }

    // Optional - Defaults to nil (OS chooses)
    public var defaultTintColor: UIColor? { palette.defaultTintColor }

    public var barButtonItemTint: UIColor? { palette.barButtonItemTint }

    #if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { palette.keyboardAppearance }
    #endif
    public var navigationBarBackgroundColor: UIColor? { palette.navigationBarBackgroundColor }

    public var settingsCellBackground: UIColor? { palette.settingsCellBackground }
    public var settingsCellText: UIColor? { palette.settingsCellText }
    public var settingsCellTextDetail: UIColor? { palette.settingsCellTextDetail }

    public var settingsHeaderBackground: UIColor? { palette.settingsHeaderBackground }
    public var settingsHeaderText: UIColor? { palette.settingsHeaderText }

#if !os(tvOS)
    public var statusBarColor: UIColor? { palette.statusBarColor }
#endif

    public var switchON: UIColor? { palette.switchON }
    public var switchThumb: UIColor? { palette.switchThumb }


//    // Mandatory
//    public let gameLibraryBackground: UIColor
//    public let gameLibraryText: UIColor
//
//    public let gameLibraryHeaderBackground: UIColor
//    public let gameLibraryHeaderText: UIColor
//
//    // Optional - Defaults to nil (OS chooses)
//    public let defaultTintColor: UIColor?
//
//    public let barButtonItemTint: UIColor?
//
//    public let keyboardAppearance: UIKeyboardAppearance
//
//    public let navigationBarBackgroundColor: UIColor?
//
//    public let settingsCellBackground: UIColor?
//    public let settingsCellText: UIColor?
//    public let settingsCellTextDetail: UIColor?
//
//    public let settingsHeaderBackground: UIColor?
//    public let settingsHeaderText: UIColor?
//
//#if !os(tvOS)
//    public let statusBarColor: UIColor?
//#else
//    public var statusBarColor: UIColor
//#endif
//
//    public let switchON: UIColor?
//    public let switchThumb: UIColor?

    /// default init
//    public init(
//        name: String,
//        defaultTintColor: UIColor? = nil,
//        barButtonItemTint: UIColor? = nil,
//
//        gameLibraryBackground: UIColor = .systemBackground,
//        gameLibraryText: UIColor = .label,
//
//        gameLibraryHeaderBackground: UIColor = .systemGroupedBackground,
//        gameLibraryHeaderText: UIColor = .label,
//
//        keyboardAppearance: UIKeyboardAppearance = .dark,
//
//        navigationBarBackgroundColor: UIColor? = nil,
//
//        settingsCellBackground: UIColor? = nil,
//        settingsCellText: UIColor? = nil,
//        settingsCellTextDetail: UIColor? = nil,
//
//        settingsHeaderBackground: UIColor? = nil,
//        settingsHeaderText: UIColor? = nil,
//
//        statusBarColor: UIColor? = nil,
//
//        switchON: UIColor? = nil,
//        switchThumb: UIColor? = nil
//    ) {
//        self.name = name
//
//        self.statusBarColor = statusBarColor
//        self.gameLibraryBackground = gameLibraryBackground
//        self.gameLibraryText = gameLibraryText
//        self.gameLibraryHeaderBackground = gameLibraryHeaderBackground
//        self.gameLibraryHeaderText = gameLibraryHeaderText
//        self.defaultTintColor = defaultTintColor
//        self.barButtonItemTint = barButtonItemTint
//        self.keyboardAppearance = keyboardAppearance
//        self.navigationBarBackgroundColor = navigationBarBackgroundColor
//        self.settingsCellBackground = settingsCellBackground
//        self.settingsCellText = settingsCellText
//        self.settingsCellTextDetail = settingsCellTextDetail
//        self.settingsHeaderBackground = settingsHeaderBackground
//        self.settingsHeaderText = settingsHeaderText
//        self.switchON = switchON
//        self.switchThumb = switchThumb
//    }


    // Custom init from Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        palette = try container.decode(iOSTheme.self, forKey: .palette)
    }

    // Custom encode to Encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(palette, forKey: .palette)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case palette
//#if !os(tvOS)
//        case statusBarColor
//#endif
//        // Mandatory
//        case gameLibraryBackground
//        case gameLibraryText
//
//        case gameLibraryHeaderBackground
//        case gameLibraryHeaderText
//
//        // Optional - Defaults to nil (OS chooses)
//        case defaultTintColor
//
//        case barButtonItemTint
//        case keyboardAppearance
//
//        case navigationBarBackgroundColor
//
//        // Optional - Defaults to nil (OS chooses)
//        case settingsCellBackground
//        case settingsCellText
//        case settingsCellTextDetail
//
//        case settingsHeaderBackground
//        case settingsHeaderText
//
//        case switchON
//        case switchThumb
    }
}
