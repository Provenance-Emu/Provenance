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
