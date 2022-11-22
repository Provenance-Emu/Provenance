//
//  PVDesmume2015Core+Options.swift
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/21/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

extension PVDesmume2015Core: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()
        
        let coreGroup = CoreOption.group(
            .init(title: "Core",
                  description: "General core options."),
            subOptions: [cpuModeOption, numberOfCoresOption, loadToMemoryOption, advancedTimingOption, frameSkipOption, firmwareLanguageOption])
        
        let videoGroup = CoreOption.group(
            .init(title: "Video",
                  description: "Video and layout options."),
            subOptions: [internalResolutionOption, screensLayoutOption, screenGapOption, hybridLayoutScaleOption, hybridShowbothScreensOption, hybridCursorAlwaysSmallscreen])
        
        let audioGroup = CoreOption.group(
            .init(title: "Audio",
                  description: "Audio output and input (mic) options."),
            subOptions: [micForceOption, micModeOption])
        
        let pointerGroup = CoreOption.group(
            .init(title: "Pointer",
                  description: "Mouse and touch options."),
            subOptions: [mouseEnabledOption, pointerTypeOption, pointerColorOption])
        
        let hacksGroup = CoreOption.group(
            .init(title: "Hacks",
                  description: "Performance hacks that work with some games better than others."),
            subOptions: [gfxEdgemark, gfxTxtHack, gfxLineHack])
        
        options.append(coreGroup)
        options.append(videoGroup)
        options.append(audioGroup)
        options.append(pointerGroup)
        options.append(hacksGroup)
        
        return options
    }()
    
    // MARK: - Core
    static let cpuModeOption: CoreOption =
        .enumeration(.init(
            title: "CPU Mode",
            description: "CPU Mode. Will default to `interpreter` if JIT is not available.",
            requiresRestart: false),
                     values:[
                        .init(title: "Interpreter", description: "Default CPU Mode", value: 0),
                        .init(title: "JIT", description: "Just-in-time CPU mode. Requires JIT activation.", value: 1),
                     ],
                     defaultValue: 0)
    
    static let numberOfCoresOption: CoreOption = .range(
        .init(title: "CPU Cores",
              description: "Number of cpu cores.",
              requiresRestart: false),
        range: .init(defaultValue: 1, min: 1, max: 4),
        defaultValue: 1)
    
    static var loadToMemoryOption: CoreOption =
        .bool(.init(title: "Load to memory",
                    description: "Load Game into Memory.",
                    requiresRestart: true),
              defaultValue: true)
    
    static var advancedTimingOption: CoreOption =
        .bool(.init(title: "Advanced Timing",
                    description: "Enable Advanced Bus-Level Timing.",
                    requiresRestart: false),
              defaultValue: true)
    
    static let frameSkipOption: CoreOption =
        .range(.init(
            title: "Frameskip",
            description: nil,
            requiresRestart: false),
               range: .init(defaultValue: 0, min: 0, max: 9),
               defaultValue: 0)
    
    static let firmwareLanguageOption: CoreOption =
        .enumeration(.init(
            title: "Firmware language",
            description: nil,
            requiresRestart: false),
                     values:[
                        // Auto|English|Japanese|French|German|Italian|Spanish
                        .init(title: "Auto", description: nil, value: 0),
                        .init(title: "English", description: nil, value: 1),
                        .init(title: "Japanese", description: nil, value: 2),
                        .init(title: "French", description: nil, value: 3),
                        .init(title: "German", description: nil, value: 4),
                        .init(title: "Italian", description: nil, value: 5),
                        .init(title: "Spanish", description: nil, value: 6),
                     ],
                     defaultValue: 0)
    
    // MARK: - Video
    
    static let internalResolutionOption: CoreOption =
        .enumeration(.init(
            title: "Internal resolution",
            description: "Resoltion that core will render internally. This is then scaled to your screen size. Sharper but possibly slower at higher values.",
            requiresRestart: true),
                     values:[
                        // 256x192|512x384|768x576|1024x768|1280x960|1536x1152|1792x1344|2048x1536|2304x1728|2560x1920
                        .init(title: "256x192", description: nil, value: 0),
                        .init(title: "512x384", description: nil, value: 1),
                        .init(title: "768x576", description: nil, value: 2),
                        .init(title: "1024x768", description: nil, value: 3),
                        .init(title: "1280x960", description: nil, value: 4),
                        .init(title: "1536x1152", description: nil, value: 5),
                        .init(title: "1792x1344", description: nil, value: 6),
                        .init(title: "2048x1536", description: nil, value: 7),
                        .init(title: "2304x1728", description: nil, value: 8),
                        .init(title: "2560x1920", description: nil, value: 9),
                     ],
                     defaultValue: 0)
    
    static let screensLayoutOption: CoreOption =
        .enumeration(.init(
            title: "Screen layout",
            description: nil,
            requiresRestart: false),
                     values:[
                        // top/bottom|bottom/top|left/right|right/left|top only|bottom only|quick switch|hybrid/top|hybrid/bottom
                        .init(title: "top/bottom", description: nil, value: 0),
                        .init(title: "bottom/top", description: nil, value: 1),
                        .init(title: "left/right", description: nil, value: 2),
                        .init(title: "right/left", description: nil, value: 3),
                        .init(title: "top only", description: nil, value: 4),
                        .init(title: "bottom only", description: nil, value: 5),
                        .init(title: "quick switch", description: nil, value: 6),
                        .init(title: "hybrid/top", description: nil, value: 7),
                        .init(title: "hybrid/bottom", description: nil, value: 8),
                     ],
                     defaultValue: 0)
    
    static let screenGapOption: CoreOption =
        .range(.init(title: "Screen gap",
                     description: nil,
                     requiresRestart: false),
               range: .init(defaultValue: 0, min: 0, max: 100),
               defaultValue: 0)
    
    static let hybridLayoutScaleOption: CoreOption =
        .enumeration(.init(
            title: "Hybrid layout scale",
            description: nil,
            requiresRestart: true),
                     values:[
                        // 1|3
                        .init(title: "1", description: nil, value: 0),
                        .init(title: "3", description: nil, value: 1),
                     ],
                     defaultValue: 0)
    
    static let hybridShowbothScreensOption: CoreOption =
        .bool(.init(title: "Hybrid layout show both screens",
                    description: nil,
                    requiresRestart: false),
              defaultValue: true)
    
    static let hybridCursorAlwaysSmallscreen: CoreOption =
        .bool(.init(title: "Cursor always smallscreen",
                    description: "Hybrid layout cursor always on small screen",
                    requiresRestart: false),
              defaultValue: true)
    
    // MARK: - Audio
    static var micForceOption: CoreOption =
        .bool(.init(title: "Force Microphone Enable",
                    description: nil,
                    requiresRestart: true),
              defaultValue: false)
    
    static let micModeOption: CoreOption =
        .enumeration(.init(
            title: "Microphone Simulation Settings",
            description: nil,
            requiresRestart: true),
                     values:[
                        // internal|sample|random|physical
                        .init(title: "internal", description: nil, value: 0),
                        .init(title: "sample", description: nil, value: 1),
                        .init(title: "random", description: nil, value: 2),
                        .init(title: "physical", description: nil, value: 3),
                     ],
                     defaultValue: 0)
    
    // MARK: - Pointer
    static var mouseEnabledOption: CoreOption =
        .bool(.init(title: "Enable mouse/pointer",
                    description: nil,
                    requiresRestart: false),
              defaultValue: true)
    
    static let pointerTypeOption: CoreOption =
        .enumeration(.init(
            title: "Pointer type",
            description: nil,
            requiresRestart: false),
                     values:[
                        // mouse|touch
                        .init(title: "mouse", description: nil, value: 0),
                        .init(title: "touch", description: nil, value: 1),
                     ],
                     defaultValue: 1)
    
    static let pointerColorOption: CoreOption =
        .enumeration(.init(
            title: "Pointer colour",
            description: nil,
            requiresRestart: true),
                     values:[
                        // white|black|red|blue|yellow
                        .init(title: "white", description: nil, value: 0),
                        .init(title: "black", description: nil, value: 1),
                        .init(title: "red", description: nil, value: 1),
                        .init(title: "blue", description: nil, value: 1),
                        .init(title: "yellow", description: nil, value: 1),
                     ],
                     defaultValue: 0)
    
    // MARK: - Hacks
    static var gfxEdgemark: CoreOption =
        .bool(.init(title: "Enable Edgemark",
                    description: nil,
                    requiresRestart: true),
              defaultValue: true)
    
    static var gfxTxtHack: CoreOption =
        .bool(.init(title: "Enable TXT hack",
                    description: nil,
                    requiresRestart: true),
              defaultValue: true)
    
    static var gfxLineHack: CoreOption =
        .bool(.init(title: "Enable line hack",
                    description: nil,
                    requiresRestart: true),
              defaultValue: false)
}

@objc public extension PVDesmume2015Core {
    // MARK: - Core
    @objc var desmume_cpuModeOption: String { PVDesmume2015Core.valueForOption(PVDesmume2015Core.cpuModeOption).asString }
    @objc var desmume_numberOfCoresOption: String { PVDesmume2015Core.valueForOption(PVDesmume2015Core.numberOfCoresOption).asString }
    @objc var desmume_loadToMemoryOption: Bool { PVDesmume2015Core.valueForOption(PVDesmume2015Core.loadToMemoryOption).asBool }
    @objc var desmume_advancedTimingOption: Bool { PVDesmume2015Core.valueForOption(PVDesmume2015Core.advancedTimingOption).asBool }
    @objc var desmume_frameSkipOption: String { PVDesmume2015Core.valueForOption(PVDesmume2015Core.frameSkipOption).asString }
    @objc var desmume_firmwareLanguageOption: String { PVDesmume2015Core.valueForOption(PVDesmume2015Core.firmwareLanguageOption).asString }
    
    // MARK: - Video
    @objc var desmume_internalResolutionOption: String { PVDesmume2015Core.valueForOption(PVDesmume2015Core.internalResolutionOption).asString }
    @objc var desmume_screensLayoutOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.screensLayoutOption).asString }
    @objc var desmume_screenGapOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.screenGapOption).asString }
    @objc var desmume_hybridLayoutScaleOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.hybridLayoutScaleOption).asString }
    @objc var desmume_hybridShowbothScreensOption: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.hybridShowbothScreensOption).asBool }
    @objc var desmume_hybridCursorAlwaysSmallscreen: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.hybridCursorAlwaysSmallscreen).asBool }
    
    // MARK: - Audio
    @objc var desmume_micForceOption: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.micForceOption).asBool }
    @objc var desmume_micModeOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.micModeOption).asString }
    
    // MARK: - Pointer
    @objc var desmume_mouseEnabledOption: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.mouseEnabledOption).asBool }
    @objc var desmume_pointerTypeOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.pointerTypeOption).asString }
    @objc var desmume_pointerColorOption: String {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.pointerColorOption).asString }
    
    // MARK: - Hacks
    @objc var desmume_gfxEdgemark: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.gfxEdgemark).asBool }
    @objc var desmume_gfxTxtHack: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.gfxTxtHack).asBool }
    @objc var desmume_gfxLineHack: Bool {
        PVDesmume2015Core.valueForOption(PVDesmume2015Core.gfxLineHack).asBool }

}
//
//#if false
//static const retro_variable values[] =
//{
//    { "desmume_internal_resolution", "Internal resolution (restart); 256x192|512x384|768x576|1024x768|1280x960|1536x1152|1792x1344|2048x1536|2304x1728|2560x1920" },
//    { "desmume_num_cores", "CPU cores; 1|2|3|4" },
//#ifdef HAVE_JIT
//#if defined(IOS) || defined(ANDROID)
//    { "desmume_cpu_mode", "CPU mode; interpreter|jit" },
//#else
//    { "desmume_cpu_mode", "CPU mode; jit|interpreter" },
//#endif
//    { "desmume_jit_block_size", "JIT block size; 12|11|10|9|8|7|6|5|4|3|2|1|0|100|99|98|97|96|95|94|93|92|91|90|89|88|87|86|85|84|83|82|81|80|79|78|77|76|75|74|73|72|71|70|69|68|67|66|65|64|63|62|61|60|59|58|57|56|55|54|53|52|51|50|49|48|47|46|45|44|43|42|41|40|39|38|37|36|35|34|33|32|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13" },
//#else
//    { "desmume_cpu_mode", "CPU mode; interpreter" },
//#endif
//    { "desmume_screens_layout", "Screen layout; top/bottom|bottom/top|left/right|right/left|top only|bottom only|quick switch|hybrid/top|hybrid/bottom" },
//    { "desmume_hybrid_layout_scale", "Hybrid layout scale (restart); 1|3"},
//    { "desmume_hybrid_showboth_screens", "Hybrid layout show both screens; enabled|disabled"},
//    { "desmume_hybrid_cursor_always_smallscreen", "Hybrid layout cursor always on small screen; enabled|disabled"},
//    { "desmume_pointer_mouse", "Enable mouse/pointer; enabled|disabled" },
//    { "desmume_pointer_type", "Pointer type; mouse|touch" },
//    { "desmume_mouse_speed", "Mouse Speed; 1.0|1.5|2.0|0.125|0.25|0.5"},
//    { "desmume_pointer_colour", "Pointer Colour; white|black|red|blue|yellow"},
//    { "desmume_pointer_device_l", "Pointer mode l-analog; none|emulated|absolute|pressed" },
//    { "desmume_pointer_device_r", "Pointer mode r-analog; none|emulated|absolute|pressed" },
//    { "desmume_pointer_device_deadzone", "Emulated pointer deadzone percent; 15|20|25|30|35|0|5|10" },
//    { "desmume_pointer_device_acceleration_mod", "Emulated pointer acceleration modifier percent; 0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50|51|52|53|54|55|56|57|58|59|60|61|62|63|64|65|66|67|68|69|70|71|72|73|74|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99|100" },
//    { "desmume_pointer_stylus_pressure", "Emulated stylus pressure modifier percent; 50|51|52|53|54|55|56|57|58|59|60|61|62|63|64|65|66|67|68|69|70|71|72|73|74|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99|100|0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|" },
//    { "desmume_pointer_stylus_jitter", "Enable emulated stylus jitter; disabled|enabled"},
//    { "desmume_load_to_memory", "Load Game into Memory (restart); disabled|enabled" },
//    { "desmume_advanced_timing", "Enable Advanced Bus-Level Timing; enabled|disabled" },
//    { "desmume_firmware_language", "Firmware language; Auto|English|Japanese|French|German|Italian|Spanish" },
//    { "desmume_frameskip", "Frameskip; 0|1|2|3|4|5|6|7|8|9" },
//    { "desmume_screens_gap", "Screen Gap; 0|5|64|90|0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50|51|52|53|54|55|56|57|58|59|60|61|62|63|64|65|66|67|68|69|70|71|72|73|74|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99|100" },
//    { "desmume_gfx_edgemark", "Enable Edgemark; enabled|disabled" },
//    { "desmume_gfx_linehack", "Enable Line Hack; enabled|disabled" },
//    { "desmume_gfx_txthack", "Enable TXT Hack; disabled|enabled"},
//    { "desmume_mic_force_enable", "Force Microphone Enable; disabled|enabled" },
//    { "desmume_mic_mode", "Microphone Simulation Settings; internal|sample|random|physical" },
//    { 0, 0 }
//};
//#endif
