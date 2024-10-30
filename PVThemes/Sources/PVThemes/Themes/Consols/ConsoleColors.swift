//
//  File.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/28/24.
//

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#elseif canImport(AppKit)
import AppKit
#endif
import HexColors

public extension UIColor {
    enum ConsoleColors: CaseIterable {
#if canImport(UIKit)
        public static let xboxLightGreen: UIColor       = #uiColor(0x77bb44)
        public static let xboxMediumGreen: UIColor      = #uiColor(0x2ca243)
        public static let xboxDarkGreen: UIColor        = #uiColor(0x107c10)
        
        public static let psxRed: UIColor               = #uiColor(0xdf0024)
        public static let psxYellow: UIColor            = #uiColor(0xf3c300)
        public static let psxCyan: UIColor              = #uiColor(0x00ab9f)
        public static let psxBlue: UIColor              = #uiColor(0x2e6db4)
        
        public static let famicomWhite: UIColor         = #uiColor(0xfcfcfc)
        public static let famicomGold: UIColor          = #uiColor(0x846d21)
        public static let famicomRed: UIColor           = #uiColor(0x940a24)
        public static let famicomGrey: UIColor          = #uiColor(0x777777)
        
        public static let gameboyGold: UIColor          = #uiColor(0x9ca04c)
        public static let gameboyGrey: UIColor          = #uiColor(0x717286)
        public static let gameboyLightGrey: UIColor     = #uiColor(0xdad6d7)
        public static let gameboyBlack: UIColor         = #uiColor(0x010105)
        public static let gameboyRed: UIColor           = #uiColor(0xad1035)

        static public var allCases: [UIColor] {
            [.ConsoleColors.xboxLightGreen, .ConsoleColors.xboxMediumGreen, .ConsoleColors.xboxDarkGreen,
             .ConsoleColors.psxRed, .ConsoleColors.psxYellow, .ConsoleColors.psxCyan, .ConsoleColors.psxBlue,
             .ConsoleColors.famicomWhite, .ConsoleColors.famicomGold, .ConsoleColors.famicomRed, .ConsoleColors.famicomGrey,
             .ConsoleColors.gameboyGold, .ConsoleColors.gameboyGrey, .ConsoleColors.gameboyLightGrey, .ConsoleColors.gameboyBlack, .ConsoleColors.gameboyRed]
        }

        static public func random() -> UIColor {
            allCases.randomElement()!
        }
#else
        public static let xboxLightGreen: UIColor       = #nsColor(0x77bb44)
        public static let xboxMediumGreen: UIColor      = #nsColor(0x2ca243)
        public static let xboxDarkGreen: UIColor        = #nsColor(0x107c10)
        
        public static let psxRed: UIColor               = #nsColor(0xdf0024)
        public static let psxYellow: UIColor            = #nsColor(0xf3c300)
        public static let psxCyan: UIColor              = #nsColor(0x00ab9f)
        public static let psxBlue: UIColor              = #nsColor(0x2e6db4)
        
        public static let famicomWhite: UIColor         = #nsColor(0xfcfcfc)
        public static let famicomGold: UIColor          = #nsColor(0x846d21)
        public static let famicomRed: UIColor           = #nsColor(0x940a24)
        public static let famicomGrey: UIColor          = #nsColor(0x777777)
        
        public static let gameboyGold: UIColor          = #nsColor(0x9ca04c)
        public static let gameboyGrey: UIColor          = #nsColor(0x717286)
        public static let gameboyLightGrey: UIColor     = #nsColor(0xdd6d7)
        public static let gameboyBlack: UIColor         = #nsColor(0x010105)
        public static let gameboyRed: UIColor           = #nsColor(0xad1035)
#endif
    }
}
