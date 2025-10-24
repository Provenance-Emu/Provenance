//
//  UIColor+Hex.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/19/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

#if canImport(UIKit)
@_exported import UIKit.UIColor
#endif

public extension UIColor {
    @objc convenience init(rgb: UInt32) {
        let rs16 = (rgb >> 16) & 0xFF
        let rs8 = (rgb >> 8) & 0xFF
        let r = rgb & 0xFF
        let red: CGFloat = CGFloat(rs16) / 255.0
        let green: CGFloat = CGFloat(rs8) / 255.0
        let blue: CGFloat = CGFloat(r) / 255.0
        let alpha: CGFloat = CGFloat(1.0)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    @objc convenience init(rgba: UInt32) {
        let red = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgba >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgba & 0xFF) / 255.0
        let alpha = CGFloat((rgba >> 24) & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    // Init a color from a hex string.
    // Supports 3, 4, 6 or 8 char lenghts #RBA #RGBA #RRGGBB #RRGGBBAA
    @objc convenience init?(hex: String) {
        // Remove #
        var hexSanitized: String = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt32 = 0
        let length: Int = hexSanitized.count

        // String to UInt32
        guard Scanner(string: hexSanitized).scanHexInt32(&rgb) else { return nil }

        switch length {
        case 3:
            let FOO: UInt32 = 0xF00
            let OFO: UInt32 = 0x0F0
            let OOF: UInt32 = 0x00F

            let rDigit: UInt32 = rgb & FOO
            let gDigit: UInt32 = rgb & OFO
            let bDigit: UInt32 = rgb & OOF

            let rShifted: UInt32 = ((rDigit << 12) | (rDigit << 8))
            let gShifted: UInt32 = ((gDigit << 8) | (gDigit << 4))
            let bShifted: UInt32 = ((bDigit << 4) | (bDigit << 0))

            let rgb: UInt32 = rShifted | gShifted | bShifted
            self.init(rgb: rgb)
            return
        case 4:
            let FOOO: UInt32 = 0xF000
            let OFOO: UInt32 = 0x0F00
            let OOFO: UInt32 = 0x00F0
            let OOOF: UInt32 = 0x000F

            let rDigit: UInt32 = rgb & FOOO
            let gDigit: UInt32 = rgb & OFOO
            let bDigit: UInt32 = rgb & OOFO
            let aDigit: UInt32 = rgb & OOOF

            let rShifted: UInt32 = ((rDigit << 16) | (rDigit << 12))
            let gShifted: UInt32 = ((gDigit << 12) | (gDigit << 8))
            let bShifted: UInt32 = ((bDigit << 8) | (bDigit << 4))
            let aShifted: UInt32 = ((aDigit << 4) | (aDigit << 0))

            let rgba: UInt32 = rShifted | gShifted | bShifted | aShifted
            self.init(rgba: rgba)
            return
        case 6:
            self.init(rgb: rgb)
        case 8:
            self.init(rgba: rgb)
            return
        default:
            return nil
        }
    }
}

public struct CodableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

//extension UIColor: Codable {
//    public struct HexValue {
//        let value: UInt32
//
//        enum CodingKeys: String, CodingKey {
//            case red
//            case green
//            case blue
//            case alpha
//        }
//
//        init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
//            self.value = UInt32((red * 255).rounded()) << 24 + (green * 255).rounded() << 16 + (blue * 255).rounded() << 8 + alpha.rounded() << 0
//        }
//
//        init(value: UInt32) {
//            self.value = value
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(HexValue(red: 0, green: 0, blue: 0), forKey: .value)
//    }
//
//    public convenience init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let red = (HexValue(red: 1, green: 0, blue: 0) & .value).rounded()
//        let green = ((HexValue(red: 0, green: 1, blue: 0) & .value)).rounded()
//        let blue = ((HexValue(red: 0, green: 0, blue: 1) & .value)).rounded()
//
//        self.init(red: red / 255.0, green: green / 255.0, blue: blue / 255.0)
//    }
//}

#if canImport(UIKit)
extension UIKeyboardAppearance: Codable { }
extension UIKeyboardAppearance: @retroactive CaseIterable {
    public static var allCases: [UIKeyboardAppearance] {
        [.default, .dark, .light, .alert]
    }
}
#endif

#if canImport(SwiftUI)
import SwiftUI
public extension Color {
    init(rgb: UInt32) {
        let rs16 = (rgb >> 16) & 0xFF
        let rs8 = (rgb >> 8) & 0xFF
        let r = rgb & 0xFF
        let red: CGFloat = CGFloat(rs16) / 255.0
        let green: CGFloat = CGFloat(rs8) / 255.0
        let blue: CGFloat = CGFloat(r) / 255.0
        let alpha: CGFloat = CGFloat(1.0)
        self.init(red: red, green: green, blue: blue)
    }

    init(rgba: UInt32) {
        let red = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgba >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgba & 0xFF) / 255.0
        let alpha = CGFloat((rgba >> 24) & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    // Init a color from a hex string.
    // Supports 3, 4, 6 or 8 char lenghts #RBA #RGBA #RRGGBB #RRGGBBAA
    init?(hex: String) {
        // Remove #
        var hexSanitized: String = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt32 = 0
        let length: Int = hexSanitized.count

        // String to UInt32
        guard Scanner(string: hexSanitized).scanHexInt32(&rgb) else { return nil }

        switch length {
        case 3:
            let FOO: UInt32 = 0xF00
            let OFO: UInt32 = 0x0F0
            let OOF: UInt32 = 0x00F

            let rDigit: UInt32 = rgb & FOO
            let gDigit: UInt32 = rgb & OFO
            let bDigit: UInt32 = rgb & OOF

            let rShifted: UInt32 = ((rDigit << 12) | (rDigit << 8))
            let gShifted: UInt32 = ((gDigit << 8) | (gDigit << 4))
            let bShifted: UInt32 = ((bDigit << 4) | (bDigit << 0))

            let rgb: UInt32 = rShifted | gShifted | bShifted
            self.init(rgb: rgb)
            return
        case 4:
            let FOOO: UInt32 = 0xF000
            let OFOO: UInt32 = 0x0F00
            let OOFO: UInt32 = 0x00F0
            let OOOF: UInt32 = 0x000F

            let rDigit: UInt32 = rgb & FOOO
            let gDigit: UInt32 = rgb & OFOO
            let bDigit: UInt32 = rgb & OOFO
            let aDigit: UInt32 = rgb & OOOF

            let rShifted: UInt32 = ((rDigit << 16) | (rDigit << 12))
            let gShifted: UInt32 = ((gDigit << 12) | (gDigit << 8))
            let bShifted: UInt32 = ((bDigit << 8) | (bDigit << 4))
            let aShifted: UInt32 = ((aDigit << 4) | (aDigit << 0))

            let rgba: UInt32 = rShifted | gShifted | bShifted | aShifted
            self.init(rgba: rgba)
            return
        case 6:
            self.init(rgb: rgb)
        case 8:
            self.init(rgba: rgb)
            return
        default:
            return nil
        }
    }
}

#endif
