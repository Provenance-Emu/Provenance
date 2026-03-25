//
//  PVDesmume2015CoreOptions.swift
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/18/25.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVSupport

@objc
@objcMembers
public class Desmume2015Options: NSObject, CoreOptions {
    // MARK: - Helpers
    private struct OptionChoice {
        let title: String
        let rawValue: String

        static func choices(_ values: [String]) -> [OptionChoice] {
            values.map { OptionChoice(title: $0, rawValue: $0) }
        }
    }

    private static func enumValues(from choices: [OptionChoice]) -> [CoreOptionEnumValue] {
        choices.enumerated().map { CoreOptionEnumValue(title: $0.element.title, value: $0.offset) }
    }

    private enum Keys {
        static let cpuMode = "desmume_cpu_mode"
        static let jitBlock = "desmume_jit_block_size"
        static let internalResolution = "desmume_internal_resolution"
        static let numCores = "desmume_num_cores"
        static let frameskip = "desmume_frameskip"
        static let loadToMemory = "desmume_load_to_memory"
        static let advancedTiming = "desmume_advanced_timing"
        static let screensLayout = "desmume_screens_layout"
        static let screensGap = "desmume_screens_gap"
        static let hybridScale = "desmume_hybrid_layout_scale"
        static let hybridShowBoth = "desmume_hybrid_showboth_screens"
        static let hybridCursorSmall = "desmume_hybrid_cursor_always_smallscreen"
        static let pointerType = "desmume_pointer_type"
        static let pointerMouse = "desmume_pointer_mouse"
        static let pointerColour = "desmume_pointer_colour"
        static let pointerDeviceL = "desmume_pointer_device_l"
        static let pointerDeviceR = "desmume_pointer_device_r"
        static let pointerDeadzone = "desmume_pointer_device_deadzone"
        static let pointerAcceleration = "desmume_pointer_device_acceleration_mod"
        static let pointerPressure = "desmume_pointer_stylus_pressure"
        static let pointerJitter = "desmume_pointer_stylus_jitter"
        static let mouseSpeed = "desmume_mouse_speed"
        static let gfxEdge = "desmume_gfx_edgemark"
        static let gfxLineHack = "desmume_gfx_linehack"
        static let gfxTextureHack = "desmume_gfx_txthack"
        static let firmwareLanguage = "desmume_firmware_language"
        static let micMode = "desmume_mic_mode"
        static let micForceEnable = "desmume_mic_force_enable"
    }

    // MARK: - Choice sets
    private static let cpuModeChoices = OptionChoice.choices(["interpreter", "jit"])
    private static let jitBlockChoices = OptionChoice.choices(["12","11","10","9","8","7","6","5","4","3","2","1","0"])
    private static let internalResolutionChoices = OptionChoice.choices([
        "256x192","512x384","768x576","1024x768","1280x960","1536x1152",
        "1792x1344","2048x1536","2304x1728","2560x1920"
    ])
    private static let coreCountChoices = OptionChoice.choices(["1","2","3","4"])
    private static let layoutChoices = OptionChoice.choices([
        "top/bottom","bottom/top","left/right","right/left",
        "top only","bottom only","quick switch","hybrid/top","hybrid/bottom"
    ])
    private static let hybridScaleChoices = OptionChoice.choices(["1","3"])
    private static let pointerTypeChoices = OptionChoice.choices(["touch","mouse"])
    private static let pointerColourChoices = OptionChoice.choices(["white","black","red","blue","yellow"])
    private static let pointerDeviceChoices = [
        OptionChoice(title: "None", rawValue: "none"),
        OptionChoice(title: "Emulated", rawValue: "emulated"),
        OptionChoice(title: "Absolute", rawValue: "absolute"),
        OptionChoice(title: "Pressed", rawValue: "pressed")
    ]
    private static let pointerDeadzoneChoices = OptionChoice.choices(["0","5","10","15","20","25","30","35"])
    private static let mouseSpeedChoices = OptionChoice.choices(["0.125","0.25","0.5","1.0","1.5","2.0"])
    private static let firmwareLanguageChoices = OptionChoice.choices(["Auto","English","Japanese","French","German","Italian","Spanish"])
    private static let micModeChoices = OptionChoice.choices(["internal","sample","random","physical"])

    // MARK: - Core options
    private static let cpuModeOption: CoreOption = {
        .enumeration(.init(title: Keys.cpuMode,
                           description: "Interpreter is most compatible. JIT is faster but less accurate.",
                           requiresRestart: true),
                     values: enumValues(from: cpuModeChoices),
                     defaultValue: 0)
    }()

    private static let jitBlockSizeOption: CoreOption = {
        .enumeration(.init(title: Keys.jitBlock,
                           description: "Instructions per JIT block (higher is faster).",
                           requiresRestart: true),
                     values: enumValues(from: jitBlockChoices),
                     defaultValue: 0)
    }()

    private static let internalResolutionOption: CoreOption = {
        let defaultIndex = internalResolutionChoices.firstIndex { $0.rawValue == "1024x768" } ?? 3
        return .enumeration(.init(title: Keys.internalResolution,
                                  description: "Internal rendering resolution (restart required).",
                                  requiresRestart: true),
                            values: enumValues(from: internalResolutionChoices),
                            defaultValue: defaultIndex)
    }()

    private static let numCoresOption: CoreOption = {
        .enumeration(.init(title: Keys.numCores,
                           description: "Number of host CPU cores Desmume can use.",
                           requiresRestart: true),
                     values: enumValues(from: coreCountChoices),
                     defaultValue: 3)
    }()

    private static let frameskipOption: CoreOption = {
        .range(.init(title: Keys.frameskip,
                     description: "Skip frames to recover performance."),
               range: .init(defaultValue: 0, min: 0, max: 9),
               defaultValue: 0)
    }()

    private static let loadToMemoryOption: CoreOption = {
        .bool(.init(title: Keys.loadToMemory,
                    description: "Load ROMs fully into memory (faster loading, higher RAM use).",
                    requiresRestart: true),
              defaultValue: true)
    }()

    private static let advancedTimingOption: CoreOption = {
        .bool(.init(title: Keys.advancedTiming,
                    description: "Enable advanced bus-level timing (slower, more accurate)."),
              defaultValue: false)
    }()

    private static let screensLayoutOption: CoreOption = {
        .enumeration(.init(title: Keys.screensLayout,
                           description: "Choose how DS screens are arranged."),
                     values: enumValues(from: layoutChoices),
                     defaultValue: 0)
    }()

    private static let screensGapOption: CoreOption = {
        .range(.init(title: Keys.screensGap,
                     description: "Gap between DS screens in pixels."),
               range: .init(defaultValue: 0, min: 0, max: 100),
               defaultValue: 0)
    }()

    private static let hybridScaleOption: CoreOption = {
        .enumeration(.init(title: Keys.hybridScale,
                           description: "Hybrid layout scale (restart required).",
                           requiresRestart: true),
                     values: enumValues(from: hybridScaleChoices),
                     defaultValue: 0)
    }()

    private static let hybridShowBothOption: CoreOption = {
        .bool(.init(title: Keys.hybridShowBoth,
                    description: "Always render both screens in hybrid mode."),
              defaultValue: true)
    }()

    private static let hybridCursorSmallOption: CoreOption = {
        .bool(.init(title: Keys.hybridCursorSmall,
                    description: "Keep stylus cursor on the small screen when using hybrid layout."),
              defaultValue: false)
    }()

    private static let pointerTypeOption: CoreOption = {
        .enumeration(.init(title: Keys.pointerType,
                           description: "Pointer backend (touch recommended)."),
                     values: enumValues(from: pointerTypeChoices),
                     defaultValue: 0)
    }()

    private static let pointerMouseOption: CoreOption = {
        .bool(.init(title: Keys.pointerMouse,
                    description: "Enable mouse/pointer events."),
              defaultValue: true)
    }()

    private static let mouseSpeedOption: CoreOption = {
        let defaultIndex = mouseSpeedChoices.firstIndex { $0.rawValue == "1.0" } ?? 3
        return .enumeration(.init(title: Keys.mouseSpeed,
                                  description: "Pointer speed multiplier."),
                            values: enumValues(from: mouseSpeedChoices),
                            defaultValue: defaultIndex)
    }()

    private static let pointerColourOption: CoreOption = {
        let defaultIndex = pointerColourChoices.firstIndex { $0.rawValue == "blue" } ?? 3
        return .enumeration(.init(title: Keys.pointerColour,
                                  description: "Pointer highlight colour."),
                            values: enumValues(from: pointerColourChoices),
                            defaultValue: defaultIndex)
    }()

    private static let pointerDeviceLOption: CoreOption = {
        .enumeration(.init(title: Keys.pointerDeviceL,
                           description: "Pointer mapping for left analog stick."),
                     values: enumValues(from: pointerDeviceChoices),
                     defaultValue: 0)
    }()

    private static let pointerDeviceROption: CoreOption = {
        .enumeration(.init(title: Keys.pointerDeviceR,
                           description: "Pointer mapping for right analog stick."),
                     values: enumValues(from: pointerDeviceChoices),
                     defaultValue: 0)
    }()

    private static let pointerDeadzoneOption: CoreOption = {
        let defaultIndex = pointerDeadzoneChoices.firstIndex { $0.rawValue == "15" } ?? 3
        return .enumeration(.init(title: Keys.pointerDeadzone,
                                  description: "Deadzone for emulated pointer (percent)."),
                            values: enumValues(from: pointerDeadzoneChoices),
                            defaultValue: defaultIndex)
    }()

    private static let pointerAccelerationOption: CoreOption = {
        .range(.init(title: Keys.pointerAcceleration,
                     description: "Acceleration modifier for emulated pointer."),
               range: .init(defaultValue: 0, min: 0, max: 100),
               defaultValue: 0)
    }()

    private static let pointerPressureOption: CoreOption = {
        .range(.init(title: Keys.pointerPressure,
                     description: "Stylus pressure modifier (percent)."),
               range: .init(defaultValue: 50, min: 0, max: 100),
               defaultValue: 50)
    }()

    private static let pointerJitterOption: CoreOption = {
        .bool(.init(title: Keys.pointerJitter,
                    description: "Simulate stylus jitter noise."),
              defaultValue: false)
    }()

    private static let gfxEdgeMarkOption: CoreOption = {
        .bool(.init(title: Keys.gfxEdge,
                    description: "Enable edgemark rendering."),
              defaultValue: false)
    }()

    private static let gfxLineHackOption: CoreOption = {
        .bool(.init(title: Keys.gfxLineHack,
                    description: "Enable line hack for certain 3D games."),
              defaultValue: false)
    }()

    private static let gfxTextureHackOption: CoreOption = {
        .bool(.init(title: Keys.gfxTextureHack,
                    description: "Enable texture hacks for missing graphics."),
              defaultValue: false)
    }()

    private static let firmwareLanguageOption: CoreOption = {
        .enumeration(.init(title: Keys.firmwareLanguage,
                           description: "Reported firmware language."),
                     values: enumValues(from: firmwareLanguageChoices),
                     defaultValue: 0)
    }()

    private static let micModeOption: CoreOption = {
        let defaultIndex = micModeChoices.firstIndex { $0.rawValue == "physical" } ?? 3
        return .enumeration(.init(title: Keys.micMode,
                                  description: "Microphone simulation mode."),
                            values: enumValues(from: micModeChoices),
                            defaultValue: defaultIndex)
    }()

    private static let micForceEnableOption: CoreOption = {
        .bool(.init(title: Keys.micForceEnable,
                    description: "Force microphone to remain enabled."),
              defaultValue: false)
    }()

    // MARK: - Public option tree
    public static var options: [CoreOption] {
        [
            .group(.init(title: "CPU & Performance", description: nil),
                   subOptions: [
                    cpuModeOption,
                    jitBlockSizeOption,
                    numCoresOption,
                    frameskipOption,
                    loadToMemoryOption,
                    advancedTimingOption
                   ]),
            .group(.init(title: "Display", description: nil),
                   subOptions: [
                    internalResolutionOption,
                    screensLayoutOption,
                    screensGapOption,
                    hybridScaleOption,
                    hybridShowBothOption,
                    hybridCursorSmallOption,
                    pointerColourOption,
                    gfxEdgeMarkOption,
                    gfxLineHackOption,
                    gfxTextureHackOption
                   ]),
            .group(.init(title: "Pointer & Touch", description: nil),
                   subOptions: [
                    pointerTypeOption,
                    pointerMouseOption,
                    mouseSpeedOption,
                    pointerDeviceLOption,
                    pointerDeviceROption,
                    pointerDeadzoneOption,
                    pointerAccelerationOption,
                    pointerPressureOption,
                    pointerJitterOption
                   ]),
            .group(.init(title: "Audio & Mic", description: nil),
                   subOptions: [
                    micModeOption,
                    micForceEnableOption
                   ]),
            .group(.init(title: "System", description: nil),
                   subOptions: [
                    firmwareLanguageOption
                   ])
        ]
    }
}

// MARK: - Variable Accessors

public extension Desmume2015Options {
    @objc(getVariable:)
    static func get(variable: String) -> Any? {
        switch variable {
        case Keys.cpuMode: return choiceValue(for: cpuModeOption, choices: cpuModeChoices)
        case Keys.jitBlock: return choiceValue(for: jitBlockSizeOption, choices: jitBlockChoices)
        case Keys.internalResolution: return choiceValue(for: internalResolutionOption, choices: internalResolutionChoices)
        case Keys.numCores: return choiceValue(for: numCoresOption, choices: coreCountChoices)
        case Keys.frameskip: return numericString(for: frameskipOption)
        case Keys.loadToMemory: return enabledDisabledString(for: loadToMemoryOption)
        case Keys.advancedTiming: return enabledDisabledString(for: advancedTimingOption)
        case Keys.screensLayout: return choiceValue(for: screensLayoutOption, choices: layoutChoices)
        case Keys.screensGap: return numericString(for: screensGapOption)
        case Keys.hybridScale: return choiceValue(for: hybridScaleOption, choices: hybridScaleChoices)
        case Keys.hybridShowBoth: return enabledDisabledString(for: hybridShowBothOption)
        case Keys.hybridCursorSmall: return enabledDisabledString(for: hybridCursorSmallOption)
        case Keys.pointerType: return choiceValue(for: pointerTypeOption, choices: pointerTypeChoices)
        case Keys.pointerMouse: return enabledDisabledString(for: pointerMouseOption)
        case Keys.pointerColour: return choiceValue(for: pointerColourOption, choices: pointerColourChoices)
        case Keys.pointerDeviceL: return choiceValue(for: pointerDeviceLOption, choices: pointerDeviceChoices)
        case Keys.pointerDeviceR: return choiceValue(for: pointerDeviceROption, choices: pointerDeviceChoices)
        case Keys.pointerDeadzone: return choiceValue(for: pointerDeadzoneOption, choices: pointerDeadzoneChoices)
        case Keys.pointerAcceleration: return numericString(for: pointerAccelerationOption)
        case Keys.pointerPressure: return numericString(for: pointerPressureOption)
        case Keys.pointerJitter: return enabledDisabledString(for: pointerJitterOption)
        case Keys.mouseSpeed: return choiceValue(for: mouseSpeedOption, choices: mouseSpeedChoices)
        case Keys.gfxEdge: return enabledDisabledString(for: gfxEdgeMarkOption)
        case Keys.gfxLineHack: return enabledDisabledString(for: gfxLineHackOption)
        case Keys.gfxTextureHack: return enabledDisabledString(for: gfxTextureHackOption)
        case Keys.firmwareLanguage:
            // When the user chose "Auto" (index 0), resolve from device locale at runtime
            let selected = valueForOption(firmwareLanguageOption).asInt ?? 0
            if selected == 0 {
                return CoreLocaleMapper.currentNDSLanguageString
            }
            return choiceValue(for: firmwareLanguageOption, choices: firmwareLanguageChoices)
        case Keys.micMode: return choiceValue(for: micModeOption, choices: micModeChoices)
        case Keys.micForceEnable: return enabledDisabledString(for: micForceEnableOption)
        default:
            WLOG("Unsupported Desmume option key: \(variable)")
            return nil
        }
    }

    // MARK: - Value helpers
    private static func choiceValue(for option: CoreOption, choices: [OptionChoice]) -> String {
        let fallback = option.defaultValue as? Int ?? 0
        let selected = valueForOption(option).asInt ?? fallback
        let safeIndex = choices.indices.contains(selected) ? selected : fallback
        return choices[safeIndex].rawValue
    }

    private static func enabledDisabledString(for option: CoreOption,
                                              enabledText: String = "enabled",
                                              disabledText: String = "disabled") -> String {
        valueForOption(option).asBool ? enabledText : disabledText
    }

    private static func numericString(for option: CoreOption) -> String {
        let fallback = option.defaultValue as? Int ?? 0
        let value = valueForOption(option).asInt ?? fallback
        return "\(value)"
    }
}
