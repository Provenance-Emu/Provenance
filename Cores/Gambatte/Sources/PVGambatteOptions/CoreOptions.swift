//
//  CoreOptions.swift
//  PVGB
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import libgambatte
import libresample

@objc public class PVGBEmulatorCoreOptions: NSObject, CoreOptions {
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: "Change the way Gambatte renders games."),
                                          subOptions: [Options.paletteOption])
        
        options.append(videoGroup)
        return options
    }
    
    public enum Options {
        public static var paletteValues: [CoreOptionEnumValue] {
            CoreOptionEnumValue.values(fromArray:
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
                                            ]) }
        
        public static var paletteOption: CoreOption {
            .enumeration(.init(title: "GameBoy Color Palette",
                               description: "Color palette to use for GameBoy (non-color) games."),
                               values: paletteValues,
                               defaultValue: 0)
        }
    }
}

@objc extension PVGBEmulatorCoreOptions {
    @objc static public func getPalette() -> GBPalette {
        let index: Int = valueForOption(Options.paletteOption)
        guard index >= 0,
              index < GBPalette.allCases.count,
              let enumValue = GBPalette(rawValue: index) else {
            ELOG("Invalid index \(index)")
            return .default
        }
        return enumValue
    }
}

