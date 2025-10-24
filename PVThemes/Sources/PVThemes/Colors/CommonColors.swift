//
//  CommmonColors.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#endif
import HexColors

public extension UIColor {
    enum Provenance {
        public static let blue: UIColor = UIColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0)
    }

#if canImport(UIKit)
    struct iOS {
        public static let blue: UIColor = #uiColor(0x007aff)
    }

    struct grey {
        public static let g333: UIColor = #uiColor(0x333)
        public static let g1C: UIColor = #uiColor(0x1C1C1C)
        public static let g6F: UIColor = #uiColor(0x6F6F6F)
        public static let g29: UIColor = #uiColor(0x292929)
        public static let gEEE: UIColor = #uiColor(0xeee)
        public static let middleGrey: UIColor = .init(white: 0.8, alpha: 1.0)
    }
    #else
    struct iOS {
        public static let blue: UIColor = #nsColor(0x007aff)
    }

    struct grey {
        public static let g333: UIColor = #nsColor(0x333)
        public static let g1C: UIColor = #nsColor(0x1C1C1C)
        public static let g6F: UIColor = #nsColor(0x6F6F6F)
        public static let g29: UIColor = #nsColor(0x292929)
        public static let gEEE: UIColor = #nsColor(0xeee)
        public static let middleGrey: UIColor = .init(white: 0.8, alpha: 1.0)
    }
    #endif
}

#if canImport(SwiftUI)
import SwiftUI
public extension Color {
    enum Provenance {
        public static let blue: Color = Color(red: 0.1, green: 0.5, blue: 0.95)
    }

    enum iOS {
        public static let blue: Color = #color(0x007aff)
    }

    enum grey {
        public static let g333: Color = #color(0x333)
        public static let g1C: Color = #color(0x1C1C1C)
        public static let g6F: Color = #color(0x6F6F6F)
        public static let g29: Color = #color(0x292929)
        public static let gEEE: Color = #color(0xeee)
        public static let middleGrey: Color = .init(white: 0.8)
    }
}
#endif

public extension UIColor {
    @available(*, deprecated, renamed: "UIColor.Provenance.blue")
    static let provenanceBlue: UIColor = UIColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0)

#if canImport(UIKit)
    @available(*, deprecated, renamed: "UIColor.iOS.blue")
    static let iosBlue: UIColor   = #uiColor(0x007aff)

    @available(*, deprecated, renamed: "UIColor.grey.g333")
    static let grey333: UIColor = #uiColor(0x333)

    @available(*, deprecated, renamed: "UIColor.grey.g1C")
    static let grey1C: UIColor = #uiColor(0x1C1C1C)

    @available(*, deprecated, renamed: "UIColor.grey.g6F")
    static let grey6F: UIColor = #uiColor(0x6F6F6F)

    @available(*, deprecated, renamed: "UIColor.grey.g29")
    static let grey29: UIColor = #uiColor(0x292929)

    @available(*, deprecated, renamed: "UIColor.grey.gEEE")
    static let greyEEE: UIColor = #uiColor(0xeee)
    #else
    @available(*, deprecated, renamed: "UIColor.iOS.blue")
    static let iosBlue: UIColor   = #nsColor(0x007aff)

    @available(*, deprecated, renamed: "UIColor.grey.g333")
    static let grey333: UIColor = #nsColor(0x333)

    @available(*, deprecated, renamed: "UIColor.grey.g1C")
    static let grey1C: UIColor = #nsColor(0x1C1C1C)

    @available(*, deprecated, renamed: "UIColor.grey.g6F")
    static let grey6F: UIColor = #nsColor(0x6F6F6F)

    @available(*, deprecated, renamed: "UIColor.grey.g29")
    static let grey29: UIColor = #nsColor(0x292929)

    @available(*, deprecated, renamed: "UIColor.grey.gEEE")
    static let greyEEE: UIColor = #nsColor(0xeee)
    #endif

    @available(*, deprecated, renamed: "UIColor.grey.middleGrey")
    static let middleGrey: UIColor = .init(white: 0.8, alpha: 1.0)
}
