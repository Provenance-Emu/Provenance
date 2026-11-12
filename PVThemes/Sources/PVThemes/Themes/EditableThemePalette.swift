import Foundation
import PVSettings
#if canImport(UIKit)
import UIKit
#endif

/// Adapts a portable palette to the app's semantic color roles.
public struct EditableThemePalette: UXThemePalette {
    public let theme: CustomTheme

    public init(theme: CustomTheme) {
        self.theme = theme
    }

    public var name: String { theme.name }
    public var dark: Bool { theme.dark }
    public var defaultTintColor: UIColor { theme.accent.platformColor }
    public var gameLibraryBackground: UIColor { theme.background.platformColor }
    public var gameLibraryText: UIColor { theme.text.platformColor }
    public var gameLibraryHeaderBackground: UIColor { theme.surface.platformColor }
    public var gameLibraryHeaderText: UIColor { defaultTintColor }
    public var gameLibraryCellBackground: UIColor? { gameLibraryHeaderBackground }
    public var settingsCellBackground: UIColor? { gameLibraryHeaderBackground }
    public var settingsCellText: UIColor? { gameLibraryText }
    public var settingsCellTextDetail: UIColor? { gameLibraryText }
    public var settingsHeaderBackground: UIColor? { gameLibraryHeaderBackground }
    public var settingsHeaderText: UIColor? { defaultTintColor }
    public var settingsSeperator: UIColor? { menuDivider }
    public var navigationBarBackgroundColor: UIColor? { gameLibraryBackground }
    public var navigationBarTitleColor: UIColor? { gameLibraryText }
    public var uiviewBackground: UIColor? { gameLibraryBackground }
    public var tableViewBackgroundColor: UIColor? { gameLibraryBackground }
    public var segmentedControlTint: UIColor? { defaultTintColor }
    public var segmentedControlSelectedTint: UIColor? { defaultTintColor }
    public var menuBackground: UIColor { gameLibraryBackground }
    public var menuText: UIColor { gameLibraryText }
    public var menuDivider: UIColor { gameLibraryText.withAlphaComponent(0.18) }
    public var menuIconTint: UIColor { defaultTintColor }
    public var menuHeaderBackground: UIColor { gameLibraryHeaderBackground }
    public var menuHeaderIconTint: UIColor { defaultTintColor }
    #if !os(tvOS)
    public var statusBarColor: UIColor? { gameLibraryBackground }
    #endif
    #if canImport(UIKit)
    public var keyboardAppearance: UIKeyboardAppearance { dark ? .dark : .light }
    #endif
}

public extension ThemeColor {
    var platformColor: UIColor {
        UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255,
                alpha: 1)
    }
}
