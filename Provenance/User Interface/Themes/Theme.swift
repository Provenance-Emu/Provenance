//
//  Test.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import UIKit

protocol tvOSTheme {
    
}

protocol iOSTheme {
    
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

    // Default to default tint (which defaults to nil)
    var barButtonItemTint: UIColor? {return defaultTintColor}
    var alertViewTintColor: UIColor? {return defaultTintColor}
    var switchON: UIColor? {return defaultTintColor}
    
    func setGlobalTint() ->  {
        // Get app delegate
        let sharedApp = UIApplication.sharedApplication()
        
        // Set tint color
        sharedApp.delegate?.window??.tintColor = self.defaultTintColor
    }
}

struct DarkTheme : iOSTheme {
    let defaultTintColor: UIColor = UIColor(hex: "#32c")!
    let keyboardAppearance: UIKeyboardAppearance = .dark
    
    let switchON = UIColor(hex: "#32c")!
    let switchThumb = UIColor(hex: "#111")!
    
    let gameLibraryBackground = UIColor.init(white: 0.1, alpha: 1)
    let gameLibraryText = UIColor.init(white: 0.8, alpha: 1)

    let gameLibraryHeaderBackground = UIColor.init(white: 0.5, alpha: 0.6)
    let gameLibraryHeaderText = UIColor.lightGray
    
    let barButtonItemTint : UIColor = UIColor.darkGray
    let navigationBarBackgroundColor: UIColor = UIColor.darkGray
    
    let alertViewBackground: UIColor = UIColor.darkGray
    let alertViewText: UIColor = UIColor.lightGray
}

struct LightTheme : iOSTheme {
    let defaultTintColor = UIColor.init(hex: "#007aff") // iOS Blue
    
    let gameLibraryBackground = UIColor.clear
    let gameLibraryText : UIColor = UIColor.black

    let gameLibraryHeaderBackground = UIColor.init(white: 0.9, alpha: 0.6)
    let gameLibraryHeaderText = UIColor.darkGray
}

@available(iOS 9.0, *)
public class Theme : NSObject {
    
    
    class func setTheme(_ theme : iOSTheme) {
        UINavigationBar.appearance().backgroundColor = theme.navigationBarBackgroundColor
        
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

        // Alert views
//        appearance(inAny: [UIAlertView.self, UIAlertController.self]) {
//            UILabel.appearance {
//                $0.textColor = theme.alertViewText
//            }
//
//            UITextView.appearance {
//                $0.textColor = theme.alertViewText
//            }
//
//            UIButton.appearance {
//                $0.tintColor = theme.alertViewText
//            }
//        }
//        UIAlertView.appearance {
//            $0.backgroundColor = theme.alertViewBackground
//            $0.tintColor = theme.alertViewTintColor
//        }
        
        // Search bar
        
            // Text color
// Swift 4 compiler error
        //        appearance(inAny: [UISearchBar.self]) {
//            UITextField.appearance {
//                $0.defaultTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
//            }
//        }

        // Game Library Headers
        PVGameLibrarySectionHeaderView.appearance {
            $0.backgroundColor = theme.gameLibraryHeaderBackground
        }
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
        UICollectionView.appearance {
            $0.backgroundColor = theme.gameLibraryBackground
        }
        
        // Keyboard Style
        UITextField.appearance {
            $0.keyboardAppearance = theme.keyboardAppearance
        }
    }
    
    @objc class func setDarkMode() {
        setTheme(DarkTheme())
    }
    
    @objc class func setLightMode() {
        setTheme(LightTheme())
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
