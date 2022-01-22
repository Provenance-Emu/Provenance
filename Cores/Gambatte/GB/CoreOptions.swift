//
//  CoreOptions.swift
//  PVGB
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport

@objc public enum GBPalette: Int {
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

extension GBPalette: CaseIterable { }

extension PVGBEmulatorCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()

		let videoGroup = CoreOption.group(.init(title: "Video",
																		  description: "Change the way Gambatte renders games."),
										  subOptions: [paletteOption])

        options.append(videoGroup)
        return options
    }()

    static let paletteValues: [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
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
    ])

	static var paletteOption: CoreOption = {
		.multi(.init(
				title: "GameBoy (non color) Palette",
				description: "The drawing palette to use"),
			values: paletteValues)
	}()
}

@objc extension PVGBEmulatorCore {
	public func setPalette() {
		let value = PVGBEmulatorCore.valueForOption(PVGBEmulatorCore.paletteOption)
		let index: Int
		switch value {
		case .bool(let bool):
			index = bool ? 0 : 1
			return
		case .string(let sstring):
			index = PVGBEmulatorCore.paletteValues.firstIndex(where: { $0.title.lowercased() == sstring }) ?? 0
		case .int(let numbert):
			index = numbert
        case .float(let numbert):
            index = Int(numbert.rounded(.towardZero))
		case .notFound:
			ELOG("Not found")
			return
		}
		guard index > 0, index <= GBPalette.allCases.count, let enumValue = GBPalette(rawValue: index) else {
			ELOG("Invalid index \(index)")
			return
		}
		changeDisplayMode(enumValue.rawValue)
	}
}
