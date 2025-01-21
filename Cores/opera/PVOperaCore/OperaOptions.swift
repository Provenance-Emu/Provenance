//
//  PVOpera+Options.swift
//  PVOpera
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging

@objc
@objcMembers
public class OperaOptions: NSObject, CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let systemGroup = CoreOption.group(.init(title: "System",
                                               description: nil),
                                         subOptions: Options.System.allCases)
        
        let graphicsGroup = CoreOption.group(.init(title: "Graphics",
                                                 description: nil),
                                           subOptions: Options.Graphics.allCases)
        
        let performanceGroup = CoreOption.group(.init(title: "Performance",
                                                    description: nil),
                                              subOptions: Options.Performance.allCases)
        
        let hacksGroup = CoreOption.group(.init(title: "Game Specific Hacks",
                                              description: nil),
                                        subOptions: Options.Hacks.allCases)
        
        options.append(contentsOf: [systemGroup, graphicsGroup, performanceGroup, hacksGroup])
        return options
    }
    
    public enum Options {
        static var allCases: [CoreOption] {
            System.allCases + Graphics.allCases + Performance.allCases + Hacks.allCases
        }
        
        public enum System: CaseIterable {
            static var allCases: [CoreOption] {
                [regionOption, activeDevicesOption, nvramStorageOption, nvramVersionOption]
            }
            
            static var regionOption: CoreOption {
                .enumeration(.init(title: "opera_region",
                                 description: "Select the resolution and field rate. NOTE: some EU games require a EU ROM.",
                                 requiresRestart: true),
                           values: [
                            .init(title: "NTSC 320x240@60", value: 0),
                            .init(title: "PAL1 320x288@50", value: 1),
                            .init(title: "PAL2 352x288@50", value: 2)
                           ],
                           defaultValue: 0)  // Default to NTSC
            }
            
            static var activeDevicesOption: CoreOption {
                .range(.init(title: "opera_active_devices",
                           description: "Number of active input devices",
                           requiresRestart: true),
                      range: .init(defaultValue: 1, min: 1, max: 8),
                      defaultValue: 1)
            }
            
            static var nvramStorageOption: CoreOption {
                .enumeration(.init(title: "opera_nvram_storage",
                                 description: "NVRAM Storage Mode"),
                           values: [
                            .init(title: "Per Game", value: 0),
                            .init(title: "Shared", value: 1)
                           ],
                           defaultValue: 0)  // Default to Per Game
            }
            
            static var nvramVersionOption: CoreOption {
                .range(.init(title: "opera_nvram_version",
                           description: "NVRAM Version"),
                      range: .init(defaultValue: 0, min: 0, max: 1),
                      defaultValue: 0)
            }
        }
        
        public enum Graphics: CaseIterable {
            static var allCases: [CoreOption] {
                [pixelFormatOption, bypassClutOption, hiResOption]
            }
            
            static var pixelFormatOption: CoreOption {
                .enumeration(.init(title: "opera_vdlp_pixel_format",
                                 description: "Pixel Format"),
                           values: [
                            .init(title: "RGB565", value: 0),
                            .init(title: "XRGB8888", value: 1)
                           ],
                           defaultValue: 0)  // Default to RGB565
            }
            
            static var bypassClutOption: CoreOption {
                .bool(.init(title: "opera_vdlp_bypass_clut",
                          description: "Bypass CLUT",
                          requiresRestart: false),
                     defaultValue: false)
            }
            
            static var hiResOption: CoreOption {
                .bool(.init(title: "opera_high_resolution",
                          description: "High Resolution",
                          requiresRestart: true),
                     defaultValue: false)
            }
        }
        
        public enum Performance: CaseIterable {
            static var allCases: [CoreOption] {
                [cpuOverclockOption, matrixEngineOption, dspThreadedOption, swiHleOption, kprintOption]
            }
            
            static var cpuOverclockOption: CoreOption {
                .enumeration(.init(title: "opera_cpu_overclock",
                                 description: "CPU Overclock"),
                           values: [
                            .init(title: "1.0x (12.50Mhz)", value: 0),
                            .init(title: "1.2x (15.00Mhz)", value: 1),
                            .init(title: "1.5x (18.75Mhz)", value: 2),
                            .init(title: "1.8x (22.50Mhz)", value: 3),
                            .init(title: "2.0x (25.00Mhz)", value: 4)
                           ],
                           defaultValue: 0)  // Default to 1.0x
            }
            
            static var matrixEngineOption: CoreOption {
                .enumeration(.init(title: "opera_madam_matrix_engine",
                                 description: "Matrix Engine"),
                           values: [
                            .init(title: "Hardware", value: 0),
                            .init(title: "Software", value: 1)
                           ],
                           defaultValue: 0)  // Default to Hardware
            }
            
            static var dspThreadedOption: CoreOption {
                .bool(.init(title: "opera_dsp_threaded",
                          description: "DSP Threaded",
                          requiresRestart: true),
                     defaultValue: false)
            }
            
            static var swiHleOption: CoreOption {
                .bool(.init(title: "opera_swi_hle",
                          description: "SWI HLE"),
                     defaultValue: false)
            }
            
            static var kprintOption: CoreOption {
                .bool(.init(title: "opera_kprint",
                          description: "Debug Output"),
                     defaultValue: false)
            }
        }
        
        public enum Hacks: CaseIterable {
            static var allCases: [CoreOption] {
                [timingHack1Option, timingHack3Option, timingHack5Option,
                 timingHack6Option, graphicsStepYOption]
            }
            
            static var timingHack1Option: CoreOption {
                .bool(.init(title: "opera_hack_timing_1",
                          description: "Timing Hack 1"),
                     defaultValue: false)
            }
            
            static var timingHack3Option: CoreOption {
                .bool(.init(title: "opera_hack_timing_3",
                          description: "Timing Hack 3 (Dinopark Tycoon)"),
                     defaultValue: false)
            }
            
            static var timingHack5Option: CoreOption {
                .bool(.init(title: "opera_hack_timing_5",
                          description: "Timing Hack 5 (Microcosm)"),
                     defaultValue: false)
            }
            
            static var timingHack6Option: CoreOption {
                .bool(.init(title: "opera_hack_timing_6",
                          description: "Timing Hack 6 (Alone in the Dark)"),
                     defaultValue: false)
            }
            
            static var graphicsStepYOption: CoreOption {
                .bool(.init(title: "opera_hack_graphics_step_y",
                          description: "Graphics Step Y Hack (Samurai Showdown)"),
                     defaultValue: false)
            }
        }
    }
}

// MARK: - Variable Accessors
public extension OperaOptions {
    @objc static var region: String { valueForOption(Options.System.regionOption).asString }
    @objc static var activeDevices: Int { valueForOption(Options.System.activeDevicesOption).asInt ?? 1 }
    @objc static var nvramStorage: String { valueForOption(Options.System.nvramStorageOption).asString }
    @objc static var nvramVersion: Int { valueForOption(Options.System.nvramVersionOption).asInt ?? 0 }
    
    @objc static var pixelFormat: String { valueForOption(Options.Graphics.pixelFormatOption).asString }
    @objc static var bypassClut: Bool { valueForOption(Options.Graphics.bypassClutOption).asBool }
    @objc static var hiRes: Bool { valueForOption(Options.Graphics.hiResOption).asBool }
    
    @objc static var cpuOverclock: String { valueForOption(Options.Performance.cpuOverclockOption).asString }
    @objc static var matrixEngine: String { valueForOption(Options.Performance.matrixEngineOption).asString }
    @objc static var dspThreaded: Bool { valueForOption(Options.Performance.dspThreadedOption).asBool }
    @objc static var swiHle: Bool { valueForOption(Options.Performance.swiHleOption).asBool }
    @objc static var kprint: Bool { valueForOption(Options.Performance.kprintOption).asBool }
    
    @objc static var timingHack1: Bool { valueForOption(Options.Hacks.timingHack1Option).asBool }
    @objc static var timingHack3: Bool { valueForOption(Options.Hacks.timingHack3Option).asBool }
    @objc static var timingHack5: Bool { valueForOption(Options.Hacks.timingHack5Option).asBool }
    @objc static var timingHack6: Bool { valueForOption(Options.Hacks.timingHack6Option).asBool }
    @objc static var graphicsStepY: Bool { valueForOption(Options.Hacks.graphicsStepYOption).asBool }
    
    @objc(getVariable:)
    static func get(variable: String) -> Any? {
        // Strip prefix if present and use base name for switch
        let baseVariable = variable.replacingOccurrences(of: "^(opera_|4do_)", with: "", options: .regularExpression)
        
        switch baseVariable {
        case "region": return region
        case "active_devices": return activeDevices
        case "nvram_storage": return nvramStorage
        case "nvram_version": return nvramVersion
        case "vdlp_pixel_format": return pixelFormat
        case "vdlp_bypass_clut": return bypassClut
        case "high_resolution": return hiRes
        case "cpu_overclock": return cpuOverclock
        case "madam_matrix_engine": return matrixEngine
        case "dsp_threaded": return dspThreaded
        case "swi_hle": return swiHle
        case "kprint": return kprint
        case "hack_timing_1": return timingHack1
        case "hack_timing_3": return timingHack3
        case "hack_timing_5": return timingHack5
        case "hack_timing_6": return timingHack6
        case "hack_graphics_step_y": return graphicsStepY
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
