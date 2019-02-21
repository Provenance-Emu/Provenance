//
//  Test.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import QuickTableViewController
import UIKit

public enum Themes: String {
    case light = "Light"
    case dark = "Dark"

    public static var defaultTheme: Themes {
        return .dark
    }

    public var theme: iOSTheme {
        switch self {
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        }
    }
}

protocol tvOSTheme {}

public protocol iOSTheme {
    var theme: Themes { get }

    var navigationBarStyle: UIBarStyle { get }

    // Mandatory
    var gameLibraryBackground: UIColor { get }
    var gameLibraryText: UIColor { get }

    var gameLibraryHeaderBackground: UIColor { get }
    var gameLibraryHeaderText: UIColor { get }

    // Optional - Defaults to nil (OS chooses)
    var defaultTintColor: UIColor? { get }

    var keyboardAppearance: UIKeyboardAppearance { get }

    var barButtonItemTint: UIColor? { get }
    var navigationBarBackgroundColor: UIColor? { get }

    var switchON: UIColor? { get }
    var switchThumb: UIColor? { get }

    var statusBarStyle: UIStatusBarStyle { get }

    var settingsHeaderBackground: UIColor? { get }
    var settingsSeperator: UIColor? { get }
    var settingsHeaderText: UIColor? { get }

    var settingsCellBackground: UIColor? { get }
    var settingsCellText: UIColor? { get }

    // Doesn't seem to be themeable
//    var alertViewBackground : UIColor {get}
//    var alertViewText : UIColor {get}
//    var alertViewTintColor : UIColor {get}
}

// Default implimentnations
extension iOSTheme {
    var keyboardAppearance: UIKeyboardAppearance { return .default }

    // Defaults to NIL will use iOS defaults
    var defaultTintColor: UIColor? { return nil }
    var switchThumb: UIColor? { return nil }
    var navigationBarBackgroundColor: UIColor? { return nil }

    var settingsHeaderBackground: UIColor? { return nil }
    var settingsHeaderText: UIColor? { return nil }
    var settingsCellBackground: UIColor? { return nil }
    var settingsCellText: UIColor? { return nil }
    var settingsSeperator: UIColor? { return nil }

    var navigationBarStyle: UIBarStyle { return .default }

    // Default to default tint (which defaults to nil)
    var barButtonItemTint: UIColor? { return defaultTintColor }
    var alertViewTintColor: UIColor? { return defaultTintColor }
    var switchON: UIColor? { return defaultTintColor }

    func setGlobalTint() {
        // Get app delegate
        let sharedApp = UIApplication.shared

        // Set tint color
        sharedApp.delegate?.window??.tintColor = defaultTintColor
    }

    var statusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
}

struct DarkTheme: iOSTheme {
    let theme = Themes.dark

    var navigationBarStyle: UIBarStyle { return UIBarStyle.black }

    var defaultTintColor: UIColor? { return UIColor(hex: "#848489")! }
    var keyboardAppearance: UIKeyboardAppearance = .dark

    var switchON: UIColor? { return UIColor(hex: "#18A9F7")! }
    var switchThumb: UIColor? { return UIColor(hex: "#eee")! }

    var gameLibraryBackground: UIColor { return UIColor.black }
    var gameLibraryText: UIColor { return UIColor(hex: "#6F6F6F")! }

    var gameLibraryHeaderBackground: UIColor { return UIColor.black }
    var gameLibraryHeaderText: UIColor { return UIColor(hex: "#333")! }

    var barButtonItemTint: UIColor? { return UIColor(hex: "#18A9F7") }
    var navigationBarBackgroundColor: UIColor? { return UIColor(hex: "#1C1C1C") }

    var alertViewBackground: UIColor { return UIColor.darkGray }
    var alertViewText: UIColor { return UIColor.lightGray }

    var statusBarStyle: UIStatusBarStyle { return UIStatusBarStyle.lightContent }

    var settingsHeaderBackground: UIColor? { return UIColor.black }
    var settingsHeaderText: UIColor? { return UIColor(white: 0.5, alpha: 1.0) }

    var settingsCellBackground: UIColor? { return UIColor(hex: "#292929")! }
    var settingsCellText: UIColor? { return UIColor(white: 0.8, alpha: 1.0) }

    var settingsSeperator: UIColor? { return UIColor.black }
}

struct LightTheme: iOSTheme {
    let theme = Themes.light

    var defaultTintColor: UIColor? { return UIColor(hex: "#007aff") } // iOS Blue

    let gameLibraryBackground = UIColor.white
    let gameLibraryText: UIColor = UIColor.black

    let gameLibraryHeaderBackground = UIColor(white: 0.9, alpha: 0.6)
    let gameLibraryHeaderText = UIColor.darkGray
}

// @available(iOS 9.0, *)
public final class Theme {
    public static var currentTheme: iOSTheme = DarkTheme() {
        didSet {
            setTheme(currentTheme)
            UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    //	class func test() {
    //		let light = AppearanceStyle("light")
    //	}

    private class func setTheme(_ theme: iOSTheme) {
        UINavigationBar.appearance {
            $0.backgroundColor = theme.navigationBarBackgroundColor
            $0.tintColor = theme.barButtonItemTint
            $0.barStyle = theme.navigationBarStyle
            $0.isTranslucent = true
        }

//        UIView.appearance {
//            $0.tintColor = theme.defaultTintColor
//        }

        UIBarButtonItem.appearance {
            $0.tintColor = theme.barButtonItemTint
        }

        UISwitch.appearance {
            $0.onTintColor = theme.switchON
            $0.thumbTintColor = theme.switchThumb
        }

        UITableView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
            $0.separatorColor = theme.settingsSeperator
        }

        SettingsTableView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
            $0.separatorColor = theme.settingsSeperator
        }

        // Settings
        appearance(in: [SettingsTableView.self]) {
            UITableViewCell.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
            }

            SwitchCell.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
//                $0.switchControl.onTintColor = theme.switchON
//                $0.switchControl.thumbTintColor = theme.switchThumb
            }

            TapActionCell.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
            }
        }

        appearance(in: [UITableViewCell.self, SwitchCell.self]) {
            UILabel.appearance {
                $0.textColor = theme.settingsCellText
            }
        }

        appearance(in: [UITableViewHeaderFooterView.self]) {
            UILabel.appearance {
                $0.textColor = theme.settingsHeaderText
            }
        }

        UITableViewHeaderFooterView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
        }

        let selectedView = UIView()
        selectedView.backgroundColor = theme.defaultTintColor

        SwitchCell.appearance().selectedBackgroundView = selectedView
        UITableViewCell.appearance().selectedBackgroundView = selectedView

        // Search bar
//        appearance(in: UISearchBar.self) {
//            UITextView.appearance {
//                $0.textColor = theme.searchTextColor
//            }
//        }

        // Game Library Headers
        PVGameLibrarySectionHeaderView.appearance {
            $0.backgroundColor = theme.gameLibraryHeaderBackground
        }

        appearance(in: [PVGameLibrarySectionHeaderView.self]) {
            UILabel.appearance {
                $0.backgroundColor = theme.gameLibraryHeaderBackground
                $0.textColor = theme.gameLibraryHeaderText
            }
        }

        // Game Library Main
        appearance(inAny: [PVGameLibraryCollectionViewCell.self]) {
            UILabel.appearance {
                $0.textColor = theme.gameLibraryText
            }
        }

//        UICollectionView.appearance {
//            $0.backgroundColor = theme.gameLibraryBackground
//        }

        // Keyboard Style
        UITextField.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }

        UISearchBar.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }

        // Force touch sheet // _UIInterfaceActionSystemRepresentationView
        if let actionSystemView = NSClassFromString("_UIInterfaceActionRepresentationsSequenceView") as? (UIView.Type) {
            actionSystemView.appearance {
                $0.backgroundColor = theme.settingsCellBackground
//                $0.layer.borderColor = theme.settingsCellText?.withAlphaComponent(0.6).cgColor
//                $0.layer.cornerRadius = 10.0
//                $0.layer.borderWidth = 0.5
                $0.tintColor = theme.gameLibraryText
            }

            appearance(inAny: [actionSystemView.self]) {
                UILabel.appearance {
                    $0.textColor = theme.gameLibraryText
                }
            }
        }
    }
}

extension Theme {
    static let lightTheme = LightTheme()
    static let darkTheme = DarkTheme()
}
