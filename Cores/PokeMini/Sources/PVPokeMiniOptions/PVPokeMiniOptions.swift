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

@objc
@objcMembers
public final class PVPokeMiniOptions: NSObject, CoreOptions, CoreOptional, Sendable {
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: Options.Video.allCases)
        
        
        options.append(videoGroup)
        
        return options
    }
    
    // MARK: Video
    package enum Options {
        package enum Video: CaseIterable {
            
            static var allCases: [CoreOption] { [videoScaleOption, paletteOption, screenShakeOption, lcdFilterOption, lcdModeOption] }
            
            
            static var videoScaleOption: CoreOption {
                .enumeration(.init(
                    title: "Video Scaling",
                    description: "Scale from the original screen size",
                    requiresRestart: true),
                             values:[
                                .init(title: "1x", description: "", value: 1),
                                .init(title: "2x", description: "", value: 2),
                                .init(title: "3x", description: "", value: 3),
                                .init(title: "4x", description: "", value: 4),
                                .init(title: "5x", description: "", value: 5),
                                .init(title: "6x", description: "", value: 6),
                             ],
                             defaultValue: 6)}
            
            package static var paletteValues: [CoreOptionEnumValue] {[
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
            ].enumerated().map{.init(title: $0.element, value: $0.offset)}}
            
            static var paletteOption: CoreOption {
                .enumeration(.init(
                    title: "PokeMini (non color) Palette",
                    description: "The drawing palette to use",
                    requiresRestart: true),
                             values:paletteValues,
                             defaultValue: 0)}
            
            static var screenShakeOption: CoreOption {
                .bool(.init(title: "Screen Shake",
                            description: "Shake screen on rumble",
                            requiresRestart: true), defaultValue: true)
            }
            
            
            package static var lcdFilterValues: [CoreOptionEnumValue] {[
                "None",          // 0
                "Dot-Matrix",   // 1
                "Scanline",     // 2
            ].enumerated().map{.init(title: $0.element, value: $0.offset)}}
            
            static var lcdFilterOption: CoreOption {
                .enumeration(.init(
                    title: "PokeMini internal LCD filter",
                    description: "Not recommended to use with CRT or LCD global shader.",
                    requiresRestart: true),
                             values:lcdFilterValues,
                             defaultValue: 1)}
            
            package static var lcdModeValues: [CoreOptionEnumValue] {[
                "Analog",          // 0
                "3 Shades",   // 1
                "2 Shades",     // 2
            ].enumerated().map{.init(title: $0.element, value: $0.offset)}}
            
            static var lcdModeOption: CoreOption {
                .enumeration(.init(
                    title: "LCD shades mode",
                    description: nil,
                    requiresRestart: true),
                             values:lcdModeValues,
                             defaultValue: 0)}
            

        }
    }
}

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

@objc extension PVPokeMiniOptions {
    @objc public static var screenShake: Bool { valueForOption(Options.Video.screenShakeOption) }
    @objc public static var palette: Int { valueForOption(Options.Video.paletteOption) }
    @objc public static var videoScale: Int { valueForOption(Options.Video.videoScaleOption) }
    @objc public static var lcdFilter: Int { valueForOption(Options.Video.lcdFilterOption) }
    @objc public static var lcdMode: Int { valueForOption(Options.Video.lcdModeOption) }
}
