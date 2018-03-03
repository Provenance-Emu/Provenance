//
//  Test.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import UIKit

public enum Themes : String {
    case light = "Light"
    case dark  = "Dark"
    
    public static var defaultTheme : Themes {
        return .light
    }
    
    public var theme : iOSTheme {
        switch self {
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        }
    }
}

protocol tvOSTheme {
}

public protocol iOSTheme {
    
    var theme : Themes {get}
    
    // Mandatory
    var gameLibraryBackground : UIColor {get}
    var gameLibraryText : UIColor {get}
    
    var gameLibraryHeaderBackground : UIColor {get}
    var gameLibraryHeaderText : UIColor {get}

    // Optional - Defaults to nil (OS chooses)
    var defaultTintColor : UIColor? {get}
    
    var keyboardAppearance : UIKeyboardAppearance {get}
    
    
    var barButtonItemTint : UIColor? {get}
    var navigationBarBackgroundColor : UIColor? {get}
    
    var switchON : UIColor? {get}
    var switchThumb : UIColor? {get}
    
    var statusBarStyle : UIStatusBarStyle {get}

    var settingsHeaderBackground : UIColor? {get}
    var settingsHeaderText: UIColor? {get}

    var settingsCellBackground: UIColor? {get}
    var settingsCellText: UIColor? {get}

    // Doesn't seem to be themeable
//    var alertViewBackground : UIColor {get}
//    var alertViewText : UIColor {get}
//    var alertViewTintColor : UIColor {get}
}

// Default implimentnations
extension iOSTheme  {
    var keyboardAppearance : UIKeyboardAppearance {return .default}

    // Defaults to NIL will use iOS defaults
    var defaultTintColor: UIColor? {return nil}
    var switchThumb: UIColor? {return nil}
    var navigationBarBackgroundColor: UIColor? {return nil}
    
    var settingsHeaderBackground: UIColor? {return nil}
    var settingsHeaderText: UIColor? {return nil}
    var settingsCellBackground: UIColor? {return nil}
    var settingsCellText: UIColor? {return nil}


    // Default to default tint (which defaults to nil)
    var barButtonItemTint: UIColor? {return defaultTintColor}
    var alertViewTintColor: UIColor? {return defaultTintColor}
    var switchON: UIColor? {return defaultTintColor}
    
    func setGlobalTint() {
        // Get app delegate
        let sharedApp = UIApplication.shared
        
        // Set tint color
        sharedApp.delegate?.window??.tintColor = self.defaultTintColor
    }
    
    var statusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
}

struct DarkTheme : iOSTheme {
    let theme = Themes.dark
    
    let defaultTintColor: UIColor = UIColor(hex: "#32c")!
    let keyboardAppearance: UIKeyboardAppearance = .dark
    
    let switchON = UIColor(hex: "#32c")!
    let switchThumb = UIColor(hex: "#111")!
    
    let gameLibraryBackground = UIColor(hex: "#292929")!
    let gameLibraryText = UIColor(hex: "#6F6F6F")!

    let gameLibraryHeaderBackground = UIColor.black
    let gameLibraryHeaderText = UIColor(hex: "#333")!
    
    let barButtonItemTint : UIColor = UIColor.darkGray
    let navigationBarBackgroundColor: UIColor = UIColor(hex: "#1C1C1C")!
    
    let alertViewBackground: UIColor = UIColor.darkGray
    let alertViewText: UIColor = UIColor.lightGray
    
    let statusBarStyle: UIStatusBarStyle = UIStatusBarStyle.lightContent
    
    let settingsHeaderBackground: UIColor = UIColor.black
    let settingsHeaderText: UIColor = UIColor(hex: "#343434")!

    let settingsCellBackground: UIColor = UIColor(hex: "#292929")!
    let settingsCellText: UIColor = UIColor(hex: "#5A5A5A")!
}

struct LightTheme : iOSTheme {
    let theme = Themes.light

    let defaultTintColor = UIColor.init(hex: "#007aff") // iOS Blue
    
    let gameLibraryBackground = UIColor.white
    let gameLibraryText : UIColor = UIColor.black

    let gameLibraryHeaderBackground = UIColor.init(white: 0.9, alpha: 0.6)
    let gameLibraryHeaderText = UIColor.darkGray
}

//@available(iOS 9.0, *)
public class Theme : NSObject {
    
    public static var currentTheme : iOSTheme = LightTheme()
    
    class func setTheme(_ theme : iOSTheme) {
        currentTheme = theme
        
        UINavigationBar.appearance {
            $0.backgroundColor = theme.navigationBarBackgroundColor
        }
        
        UIView.appearance {
            $0.tintColor = theme.defaultTintColor
        }
        
        UIBarButtonItem.appearance {
            $0.tintColor = theme.barButtonItemTint
        }
        
        UISwitch.appearance {
            $0.onTintColor = theme.switchON
            $0.thumbTintColor = theme.switchThumb
        }


        // Settings
//        UITableViewCell.appearance {
//            $0.backgroundColor = theme.settingsCellBackground
//            $0.textLabel?.textColor = theme.settingsCellText
//            $0.detailTextLabel?.textColor = theme.settingsCellText
//        }
//        
//        appearance(in: UITableViewCell.self) {
//            UILabel.appearance {
//                $0.textColor = theme.settingsCellText
//            }
//        }
//
//        UITableViewHeaderFooterView.appearance {
//            $0.backgroundColor = theme.settingsHeaderBackground
//        }
//
//        appearance(in: UITableViewHeaderFooterView.self) {
//            UILabel.appearance {
//                $0.textColor = theme.settingsHeaderText
//            }
//        }
//        
//        UITableView.appearance {
//            // TODO
//            $0.backgroundColor = theme.settingsHeaderBackground
//        }
//        
        
        
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
        
        // Appearacne in is only in 9+
        if #available(iOS 9.0, *) {
            appearance(in: PVGameLibrarySectionHeaderView.self) {
                UILabel.appearance {
                    $0.backgroundColor = theme.gameLibraryHeaderBackground
                    $0.textColor = theme.gameLibraryHeaderText
                }
            }
            
            // Game Library Main
            appearance(inAny: [UICollectionView.self, PVGameLibraryCollectionViewCell.self]) {
                UILabel.appearance {
                    $0.textColor = theme.gameLibraryText // !!! Why isn't this working?
                }
            }
        }
        
        UICollectionView.appearance {
            $0.backgroundColor = theme.gameLibraryBackground
        }
        
        // Keyboard Style
        UITextField.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }
        
        // Status bar
        UIApplication.shared.statusBarStyle = theme.statusBarStyle
    }    
}

extension UIColor {
    
    convenience init(rgb: UInt32) {
        let red = CGFloat((rgb >> 16) & 0xff) / 255.0
        let green = CGFloat((rgb >> 8) & 0xff) / 255.0
        let blue = CGFloat(rgb & 0xff) / 255.0
        let alpha = CGFloat(1.0)
        self.init(red: red, green: green, blue: blue, alpha: alpha);
    }
    
    convenience init(rgba: UInt32) {
        let red = CGFloat((rgba >> 16) & 0xff) / 255.0
        let green = CGFloat((rgba >> 8) & 0xff) / 255.0
        let blue = CGFloat(rgba & 0xff) / 255.0
        let alpha = CGFloat((rgba >> 24) & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha);
    }
    
    // Init a color from a hex string.
    // Supports 3, 4, 6 or 8 char lenghts #RBA #RGBA #RRGGBB #RRGGBBAA
    convenience init?(hex: String) {
        
        // Remove #
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt32 = 0
        let length = hexSanitized.count
        
        // String to UInt32
        guard Scanner(string: hexSanitized).scanHexInt32(&rgb) else { return nil }
        
        if length == 3 {
            let rDigit = rgb & 0xF00
            let gDigit = rgb & 0x0F0
            let bDigit = rgb & 0x00F
            
            let rShifted = ((rDigit << 12) | (rDigit << 8))
            let gShifted = ((gDigit << 8) | (gDigit << 4))
            let bShifted = ((bDigit << 4) | (bDigit << 0))

            let rgb = rShifted | gShifted | bShifted
            self.init(rgb: rgb)
            return
        } else if length == 4 {
            let rDigit = rgb & 0xF000
            let gDigit = rgb & 0x0F00
            let bDigit = rgb & 0x00F0
            let aDigit = rgb & 0x000F
            
            let rShifted = ((rDigit << 16) | (rDigit << 12))
            let gShifted = ((gDigit << 12) | (gDigit << 8))
            let bShifted = ((bDigit << 8) | (bDigit << 4))
            let aShifted = ((aDigit << 4) | (aDigit << 0))
            
            let rgba = rShifted | gShifted | bShifted | aShifted
            self.init(rgba: rgba)
            return
        } else if length == 6 {
            self.init(rgb: rgb)
        } else if length == 8 {
            self.init(rgba: rgb)
            return
        } else {
            return nil
        }
    }
}
