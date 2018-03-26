//
//  UIColor+Hex.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/19/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

public extension UIColor {

    @objc convenience init(rgb: UInt32) {
        let red = CGFloat((rgb >> 16) & 0xff) / 255.0
        let green = CGFloat((rgb >> 8) & 0xff) / 255.0
        let blue = CGFloat(rgb & 0xff) / 255.0
        let alpha = CGFloat(1.0)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    @objc convenience init(rgba: UInt32) {
        let red = CGFloat((rgba >> 16) & 0xff) / 255.0
        let green = CGFloat((rgba >> 8) & 0xff) / 255.0
        let blue = CGFloat(rgba & 0xff) / 255.0
        let alpha = CGFloat((rgba >> 24) & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    // Init a color from a hex string.
    // Supports 3, 4, 6 or 8 char lenghts #RBA #RGBA #RRGGBB #RRGGBBAA
    @objc convenience init?(hex: String) {

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
