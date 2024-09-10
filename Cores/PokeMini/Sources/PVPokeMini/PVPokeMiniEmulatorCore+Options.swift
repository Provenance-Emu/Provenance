//
//  PVTGBDualCore+Options.swift
//  PVTGBDualCore
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging
import libpokemini
import PVEmulatorCore

/*
 { "pokemini_video_scale", "Video Scale (Restart); 4x|5x|6x|1x|2x|3x" },
 { "pokemini_lcdfilter", "LCD Filter; dotmatrix|scanline|none" },
 { "pokemini_lcdmode", "LCD Mode; analog|3shades|2shades" },
 { "pokemini_lcdcontrast", "LCD Contrast; 64|0|16|32|48|80|96" },
 { "pokemini_lcdbright", "LCD Brightness; 0|-80|-60|-40|-20|20|40|60|80" },
 { "pokemini_palette", "Palette; Default|Old|Monochrome|Green|Green Vector|Red|Red Vector|Blue LCD|LEDBacklight|Girl Power|Blue|Blue Vector|Sepia|Monochrome Vector" },
 { "pokemini_piezofilter", "Piezo Filter; enabled|disabled" },
 { "pokemini_rumblelvl", "Rumble Level (Screen + Controller); 3|2|1|0" },
 { "pokemini_controller_rumble", "Controller Rumble; enabled|disabled" },
 { "pokemini_screen_shake", "Screen Shake; enabled|disabled" },
 */

extension PVPokeMiniEmulatorCore: @preconcurrency CoreOptional {
    @MainActor public static var options: [CoreOption] {
        var options = [CoreOption]()

        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [videoScaleOption, paletteOption, screenShakeOption])


        options.append(videoGroup)

        return options
    }

    // MARK: Video
    
    @MainActor static let videoScaleValues: [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
        [
            "4x",   // 0
            "5x",   // 1
            "6x",   // 2
            "1x",   // 3
            "2x",   // 4
            "3x",   // 5
    ])
    
    @MainActor static var videoScaleOption: CoreOption = {
        .multi(.init(
                title: "Video Scaling",
                description: "Scale from the original screen size"),
            values: videoScaleValues)
    }()

    @MainActor static let paletteValues: [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
        [
            "Default",          // 0
            "Old",              // 1
            "Monochrome",       // 2
            "Green",            // 3
            "Green Vector",     // 4
            "Red",              // 5
            "Red Vector",       // 6
            "Blue LCD",         // 7
            "LEDBacklight",     // 8
            "Girl Power",       // 9
            "Blue",             // 10
            "Blue Vector",      // 11
            "Sepia",            // 12
            "Monochrome Vector" // 13
    ])

    @MainActor static var paletteOption: CoreOption = {
        .multi(.init(
                title: "PokeMini (non color) Palette",
                description: "The drawing palette to use"),
            values: paletteValues)
    }()
    
    @MainActor static var screenShakeOption: CoreOption {
        .bool(.init(title: "Screen Shake",
                    description: "Shake screen on rumble",
                    requiresRestart: true), defaultValue: true)
    }

    @MainActor
    public func get(variable: String) -> Any? {
        switch variable {
        case "pokemini_screen_shake":
            return Self.valueForOption(Self.screenShakeOption).asBool
        case "pokemini_video_scale":
            switch Self.valueForOption(Self.videoScaleOption).asInt ?? 0 {
            case 0: return "4x"
            case 1: return "5x"
            case 2: return "6x"
            case 3: return "1x"
            case 4: return "2x"
            case 5: return "3x"
            default: return "4x"
            }
        case "pokemini_palette":
            switch Self.valueForOption(Self.paletteOption).asInt ?? 0 {
            case 0: return "Default"
            case 1: return "Old"
            case 2: return "Monochrome"
            case 3: return "Green"
            case 4: return "Green Vector"
            case 5: return "Red"
            case 6: return "Red Vector"
            case 7: return "Blue LCD"
            case 8: return "LEDBacklight"
            case 9: return "Girl Power"
            case 10: return "Blue"
            case 11: return "Blue Vector"
            case 12: return "Sepia"
            case 13: return "Monochrome Vector"
            default: return "Default"
            }
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
