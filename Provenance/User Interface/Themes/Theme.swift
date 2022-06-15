//
//  Test.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

import UIKit

public extension UIColor {
    static let provenanceBlue: UIColor = UIColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0)
    static let iosBlue: UIColor   = .init(hex: "#007aff")!
    static let grey333: UIColor = .init(hex: "#333")!
    static let grey1C: UIColor = .init(hex: "#1C1C1C")!
    static let grey6F: UIColor = .init(hex: "#6F6F6F")!
    static let grey29: UIColor = .init(hex: "#292929")!
    static let greyEEE: UIColor = .init(hex: "#eee")!
    static let middleGrey: UIColor = .init(white: 0.8, alpha: 1.0)
}

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

    #if !os(tvOS)
    var navigationBarStyle: UIBarStyle { get }
    var statusBarStyle: UIStatusBarStyle { get }
    #endif
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

    var statusBarColor: UIColor? { get }

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

    #if !os(tvOS)
    var navigationBarStyle: UIBarStyle { return .default }
    var statusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
    #endif
    var statusBarColor: UIColor? { return nil }

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


}

struct DarkTheme: iOSTheme {
    enum Colors {
        static let lightBlue: UIColor   = .init(hex: "#18A9F7")!
        static let blueishGrey: UIColor = .init(hex: "#848489")!
    }
    
    let theme = Themes.dark

    #if !os(tvOS)
    var navigationBarStyle: UIBarStyle { return UIBarStyle.black }
    var statusBarStyle: UIStatusBarStyle { return UIStatusBarStyle.lightContent }
    #endif
    var defaultTintColor: UIColor? { return Colors.blueishGrey }
    var keyboardAppearance: UIKeyboardAppearance = .dark

    var switchON: UIColor? { return Colors.lightBlue }
    var switchThumb: UIColor? { return .greyEEE }

    var gameLibraryBackground: UIColor { return .black }
    var gameLibraryText: UIColor { return .grey6F}

    var gameLibraryHeaderBackground: UIColor { return UIColor.black }
    var gameLibraryHeaderText: UIColor { return .grey333}

    var barButtonItemTint: UIColor? { return Colors.lightBlue }
    var navigationBarBackgroundColor: UIColor? { return .grey1C }

    var alertViewBackground: UIColor { return .darkGray }
    var alertViewText: UIColor { return .lightGray }


    var settingsHeaderBackground: UIColor? { return .black }
    var settingsHeaderText: UIColor? { return .middleGrey }

    var settingsCellBackground: UIColor? { return .grey29 }
    var settingsCellText: UIColor? { return .middleGrey  }

    var settingsSeperator: UIColor? { return .black }
}

struct LightTheme: iOSTheme {
    let theme = Themes.light
    
    enum Colors {
        static let white9alpha6 = UIColor(white: 0.9, alpha: 0.6)
    }
    

    var defaultTintColor: UIColor? { return .iosBlue } // iOS Blue

    let gameLibraryBackground: UIColor = .white
    let gameLibraryText: UIColor = .black

    let gameLibraryHeaderBackground: UIColor = Colors.white9alpha6
    let gameLibraryHeaderText: UIColor = .darkGray
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
    static weak var statusBarView: UIView?
    private class func styleStatusBar(withColor color: UIColor? = nil) {
        #if !os(tvOS)
        guard let color = color else {
            if let statusBarView = statusBarView {
                statusBarView.removeFromSuperview()
            }
            return
        }
        if #available(iOS 13.0, *) {
            guard
                let window = UIApplication.shared.keyWindow,
                let scene = window.windowScene,
                let manager = scene.statusBarManager else {
                ELOG("check your tcp/ip's")
                return
            }
            let statusBar1 = statusBarView ?? UIView()
            statusBar1.frame = manager.statusBarFrame
            statusBar1.backgroundColor = color
            statusBarView = statusBar1
            window.addSubview(statusBar1)
        } else {
            if let statusBar1: UIView = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                statusBar1.backgroundColor = color
            }
        }
        #endif
    }

    private class func setTheme(_ theme: iOSTheme) {
        UINavigationBar.appearance {
            $0.backgroundColor = theme.navigationBarBackgroundColor
            $0.tintColor = theme.barButtonItemTint
            #if !os(tvOS)
            $0.barStyle = theme.navigationBarStyle
            #endif
            $0.isTranslucent = true
        }

//        UIView.appearance {
//            $0.tintColor = theme.defaultTintColor
//        }

        UIBarButtonItem.appearance {
            $0.tintColor = theme.barButtonItemTint
        }

        #if !os(tvOS)
        UISwitch.appearance {
            $0.onTintColor = theme.switchON
			#if !targetEnvironment(macCatalyst)
            $0.thumbTintColor = theme.switchThumb
			#endif
        }

        UITableView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
            $0.separatorColor = theme.settingsSeperator
        }

        SettingsTableView.appearance {
            $0.backgroundColor = theme.settingsHeaderBackground
            $0.separatorColor = theme.settingsSeperator
        }
        #endif

        // Settings
        appearance(inAny: [PVSettingsViewController.self, SystemsSettingsTableViewController.self, CoreOptionsViewController.self, SettingsTableView.self, PVAppearanceViewController.self, PVCoresTableViewController.self]) {
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
        
        // Status bar
        styleStatusBar(withColor: theme.statusBarColor)
    }
}

extension Theme {
    static let lightTheme = LightTheme()
    static let darkTheme = DarkTheme()
}
