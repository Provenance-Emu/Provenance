//
//  CoreOptions.swift
//  PVGB
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport

@objc public enum GBPalette : Int {
	case peaSoupGreen
	case pocket
	case blue
	case darkBlue
	case green
	case darkGreen
	case brown
	case darkBrown
	case red
	case yellow
	case orange
	case pastelMix
	case inverted
	case romTitle
	case grayscale
}

extension PVGBEmulatorCore : CoreOptional {

	public static var options: [CoreOption] = {
		var options = [CoreOption]()

		let videoGroup = CoreOption.group(display: CoreOptionValueDisplay(title: "Video", description: nil), subOptions: [paletteOption])

		options.append(videoGroup)
		return options
	}()

	static let paletteValues : [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
		[
			"Pea Soup Green",
			"GameBoy Pocket",
			"GameBoy Color - Blue",
			"GameBoy Color - Dark Blue",
			"GameBoy Color - Green",
			"GameBoy Color - Dark Green",
			"GameBoy Color - Brown",
			"GameBoy Color - Dark Brown",
			"GameBoy Color - Red",
			"GameBoy Color - Yellow",
			"GameBoy Color - Orange",
			"GameBoy Color - Pastel Mix",
			"GameBoy Color - Inverted",
			"GameBoy Color - Rom Title",
			"GameBoy Color - Grayscale"
			]
	)

	static var paletteOption : CoreOption = {

		let palletteOption = CoreOption.multi(display: CoreOptionValueDisplay(title: "GameBoy (non color) Palette", description: "The drawing palette to use"), values: paletteValues)
		return palletteOption
	}()
}

@objc extension PVGBEmulatorCore {
	public func setPalette() {
		if
			let value = PVGBEmulatorCore.valueForOption(String.self, "Video.GameBoy (non color) Palette"),
			let index = PVGBEmulatorCore.paletteValues.index(where: {return $0.title == value}),
			let enumValue = GBPalette(rawValue: index) {
			changeDisplayMode(enumValue.rawValue)
		}
	}
}
