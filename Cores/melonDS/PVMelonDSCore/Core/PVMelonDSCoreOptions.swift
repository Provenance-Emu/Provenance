//
//  PVMelonDSCoreOptions.swift
//  PVMelonDS
//
//  Created by Joseph Mattiello on 11/18/25.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVSupport

@objc
@objcMembers
public class MelonDSOptions: NSObject, CoreOptions {
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
        static let consoleMode = "melonds_console_mode"
        static let bootDirectly = "melonds_boot_directly"
        static let screenLayout = "melonds_screen_layout"
        static let screenGap = "melonds_screen_gap"
        static let hybridSmallScreen = "melonds_hybrid_small_screen"
        static let swapScreenMode = "melonds_swapscreen_mode"
        static let randomizeMAC = "melonds_randomize_mac_address"
        static let threadedRenderer = "melonds_threaded_renderer"
        static let touchMode = "melonds_touch_mode"
        static let hybridRatio = "melonds_hybrid_ratio"
        static let openglRenderer = "melonds_opengl_renderer"
        static let openglResolution = "melonds_opengl_resolution"
        static let openglBetterPolygons = "melonds_opengl_better_polygons"
        static let openglFiltering = "melonds_opengl_filtering"
        static let jitEnable = "melonds_jit_enable"
        static let jitBlockSize = "melonds_jit_block_size"
        static let jitBranchOpt = "melonds_jit_branch_optimisations"
        static let jitLiteralOpt = "melonds_jit_literal_optimisations"
        static let jitFastMemory = "melonds_jit_fast_memory"
        static let dsiSD = "melonds_dsi_sdcard"
        static let audioBitrate = "melonds_audio_bitrate"
        static let audioInterpolation = "melonds_audio_interpolation"
        static let firmwareLanguage = "melonds_language"
    }

    // MARK: - Choices
    private static let consoleModeChoices = OptionChoice.choices(["DS", "DSi"])
    private static let screenLayoutChoices = OptionChoice.choices([
        "Top/Bottom", "Bottom/Top", "Left/Right", "Right/Left",
        "Top Only", "Bottom Only", "Hybrid Top", "Hybrid Bottom"
    ])
    private static let hybridSmallScreenChoices = OptionChoice.choices(["Bottom", "Top", "Duplicate"])
    private static let swapScreenModeChoices = OptionChoice.choices(["Toggle", "Hold"])
    private static let touchModeChoices = OptionChoice.choices(["disabled", "Mouse", "Touch", "Joystick"])
    private static let hybridRatioChoices = OptionChoice.choices(["2", "3"])
    private static let openglFilteringChoices = OptionChoice.choices(["nearest", "linear"])
    private static let audioBitrateChoices = OptionChoice.choices(["Automatic", "10-bit", "16-bit"])
    private static let audioInterpolationChoices = OptionChoice.choices(["None", "Linear", "Cosine", "Cubic"])
    // NDS firmware language — "Auto" resolves to device locale at runtime
    private static let firmwareLanguageChoices = OptionChoice.choices(["Auto", "Japanese", "English", "French", "German", "Italian", "Spanish"])

    private static let screenGapRange = CoreOptionRange(defaultValue: 0, min: 0, max: 192)
    private static let jitBlockRange = CoreOptionRange(defaultValue: 32, min: 1, max: 100)

    private static let openglResolutionChoices: [OptionChoice] = {
        let baseWidth = 256
        let baseHeight = 192
        return (1...8).map { scale in
            let label = "\(scale)x native (\(baseWidth * scale)x\(baseHeight * scale))"
            return OptionChoice(title: label, rawValue: label)
        }
    }()

    // MARK: - Core options
    private static let consoleModeOption = CoreOption.enumeration(
        .init(title: Keys.consoleMode,
              description: "Choose between DS and DSi emulation.",
              requiresRestart: true),
        values: enumValues(from: consoleModeChoices),
        defaultValue: 0
    )

    private static let bootDirectlyOption = CoreOption.bool(
        .init(title: Keys.bootDirectly,
              description: "Boot directly into the game instead of the BIOS menu."),
        defaultValue: true
    )

    /// Default DS screen layout.
    /// On tvOS the device is always in landscape and there is no user-facing
    /// rotation, so a vertically-stacked Top/Bottom layout produces a tall
    /// portrait framebuffer that gets letterboxed on the TV (the "DS stuck in
    /// portrait" tester report). Default to Left/Right (index 2) on tvOS so the
    /// two DS screens sit side-by-side and fill the landscape display.
    private static let screenLayoutDefault: Int = {
        #if os(tvOS)
        return 2 // Left/Right
        #else
        return 0 // Top/Bottom
        #endif
    }()

    private static let screenLayoutOption = CoreOption.enumeration(
        .init(title: Keys.screenLayout,
              description: "Arrange the two DS screens."),
        values: enumValues(from: screenLayoutChoices),
        defaultValue: screenLayoutDefault
    )

    private static let screenGapOption = CoreOption.range(
        .init(title: Keys.screenGap,
              description: "Gap between DS screens in pixels."),
        range: screenGapRange,
        defaultValue: screenGapRange.defaultValue
    )

    private static let hybridSmallScreenOption = CoreOption.enumeration(
        .init(title: Keys.hybridSmallScreen,
              description: "Which screen appears in the hybrid layout's small window."),
        values: enumValues(from: hybridSmallScreenChoices),
        defaultValue: 0
    )

    private static let swapScreenModeOption = CoreOption.enumeration(
        .init(title: Keys.swapScreenMode,
              description: "Toggle vs hold behavior when swapping screens."),
        values: enumValues(from: swapScreenModeChoices),
        defaultValue: 0
    )

    private static let randomMacOption = CoreOption.bool(
        .init(title: Keys.randomizeMAC,
              description: "Randomize the console MAC address."),
        defaultValue: false
    )

#if !os(macOS)
    private static let threadedRendererOption = CoreOption.bool(
        .init(title: Keys.threadedRenderer,
              description: "Enable threaded software renderer (software mode only)."),
        defaultValue: true
    )
#endif

    private static let touchModeOption = CoreOption.enumeration(
        .init(title: Keys.touchMode,
              description: "Touch input backend."),
        values: enumValues(from: touchModeChoices),
        defaultValue: 2 // Touch
    )

    private static let hybridRatioOption = CoreOption.enumeration(
        .init(title: Keys.hybridRatio,
              description: "Hybrid layout ratio (OpenGL only)."),
        values: enumValues(from: hybridRatioChoices),
        defaultValue: 0
    )

    private static let openglRendererOption = CoreOption.bool(
        .init(title: Keys.openglRenderer,
              description: "Use the OpenGL renderer (requires restart).",
              requiresRestart: true),
        defaultValue: true
    )

    private static let openglResolutionOption = CoreOption.enumeration(
        .init(title: Keys.openglResolution,
              description: "Internal OpenGL resolution scale."),
        values: enumValues(from: openglResolutionChoices),
        defaultValue: 0
    )

    private static let openglBetterPolygonsOption = CoreOption.bool(
        .init(title: Keys.openglBetterPolygons,
              description: "Improve polygon splitting accuracy (OpenGL)."),
        defaultValue: true
    )

    private static let openglFilteringOption = CoreOption.enumeration(
        .init(title: Keys.openglFiltering,
              description: "Texture filtering for OpenGL renderer."),
        values: enumValues(from: openglFilteringChoices),
        defaultValue: 1 // linear
    )

    private static let jitEnableOption = CoreOption.bool(
        .init(title: Keys.jitEnable,
              description: "Enable the JIT recompiler (restart required).",
              requiresRestart: true),
        defaultValue: false
    )

    private static let jitBlockSizeOption = CoreOption.range(
        .init(title: Keys.jitBlockSize,
              description: "Instructions per JIT block (higher is faster).",
              requiresRestart: true),
        range: jitBlockRange,
        defaultValue: jitBlockRange.defaultValue
    )

    private static let jitBranchOption = CoreOption.bool(
        .init(title: Keys.jitBranchOpt,
              description: "Enable branch optimizations in JIT."),
        defaultValue: true
    )

    private static let jitLiteralOption = CoreOption.bool(
        .init(title: Keys.jitLiteralOpt,
              description: "Enable literal optimizations in JIT."),
        defaultValue: true
    )

    private static let jitFastMemoryOption = CoreOption.bool(
        .init(title: Keys.jitFastMemory,
              description: "Enable fast memory access in JIT."),
        defaultValue: true
    )

    private static let dsiSDOption = CoreOption.bool(
        .init(title: Keys.dsiSD,
              description: "Expose the DSi SD card to software."),
        defaultValue: false
    )

    private static let audioBitrateOption = CoreOption.enumeration(
        .init(title: Keys.audioBitrate,
              description: "Audio bit depth."),
        values: enumValues(from: audioBitrateChoices),
        defaultValue: 2 // 16-bit
    )

    private static let audioInterpolationOption = CoreOption.enumeration(
        .init(title: Keys.audioInterpolation,
              description: "Audio interpolation quality."),
        values: enumValues(from: audioInterpolationChoices),
        defaultValue: 3 // Cubic
    )

    private static let firmwareLanguageOption = CoreOption.enumeration(
        .init(title: Keys.firmwareLanguage,
              description: "NDS firmware language. 'Auto' follows the device locale.",
              requiresRestart: true),
        values: enumValues(from: firmwareLanguageChoices),
        defaultValue: 0 // Auto
    )

    // MARK: - Option tree
    public static var options: [CoreOption] {
        var groups: [CoreOption] = [
            .group(.init(title: "Console", description: nil),
                   subOptions: [
                    consoleModeOption,
                    bootDirectlyOption,
                    randomMacOption,
                    dsiSDOption,
                    firmwareLanguageOption
                   ]),
            .group(.init(title: "Display & Layout", description: nil),
                   subOptions: [
                    screenLayoutOption,
                    screenGapOption,
                    hybridSmallScreenOption,
                    swapScreenModeOption,
                    hybridRatioOption
                   ]),
            .group(.init(title: "Touch & Input", description: nil),
                   subOptions: [
                    touchModeOption
                   ])
        ]

#if !os(macOS)
        groups[2] = .group(.init(title: "Touch & Input", description: nil),
                           subOptions: [
                            touchModeOption,
                            threadedRendererOption
                           ])
#endif

        groups.append(
            .group(.init(title: "OpenGL Renderer", description: nil),
                   subOptions: [
                    openglRendererOption,
                    openglResolutionOption,
                    openglBetterPolygonsOption,
                    openglFilteringOption
                   ])
        )

        groups.append(
            .group(.init(title: "JIT Compiler", description: nil),
                   subOptions: [
                    jitEnableOption,
                    jitBlockSizeOption,
                    jitBranchOption,
                    jitLiteralOption,
                    jitFastMemoryOption
                   ])
        )

        groups.append(
            .group(.init(title: "Audio", description: nil),
                   subOptions: [
                    audioBitrateOption,
                    audioInterpolationOption
                   ])
        )

        return groups
    }
}

// MARK: - Variable accessors
public extension MelonDSOptions {
    @objc(getVariable:)
    static func get(variable: String) -> Any? {
        switch variable {
        case Keys.consoleMode: return choiceValue(for: consoleModeOption, choices: consoleModeChoices)
        case Keys.bootDirectly: return enabledDisabledString(for: bootDirectlyOption)
        case Keys.screenLayout: return choiceValue(for: screenLayoutOption, choices: screenLayoutChoices)
        case Keys.screenGap: return numericString(for: screenGapOption)
        case Keys.hybridSmallScreen: return choiceValue(for: hybridSmallScreenOption, choices: hybridSmallScreenChoices)
        case Keys.swapScreenMode: return choiceValue(for: swapScreenModeOption, choices: swapScreenModeChoices)
        case Keys.randomizeMAC: return enabledDisabledString(for: randomMacOption)
#if !os(macOS)
        case Keys.threadedRenderer: return enabledDisabledString(for: threadedRendererOption)
#endif
        case Keys.touchMode: return choiceValue(for: touchModeOption, choices: touchModeChoices)
        case Keys.hybridRatio: return choiceValue(for: hybridRatioOption, choices: hybridRatioChoices)
        case Keys.openglRenderer: return enabledDisabledString(for: openglRendererOption)
        case Keys.openglResolution: return choiceValue(for: openglResolutionOption, choices: openglResolutionChoices)
        case Keys.openglBetterPolygons: return enabledDisabledString(for: openglBetterPolygonsOption)
        case Keys.openglFiltering: return choiceValue(for: openglFilteringOption, choices: openglFilteringChoices)
        case Keys.jitEnable: return enabledDisabledString(for: jitEnableOption)
        case Keys.jitBlockSize: return numericString(for: jitBlockSizeOption)
        case Keys.jitBranchOpt: return enabledDisabledString(for: jitBranchOption)
        case Keys.jitLiteralOpt: return enabledDisabledString(for: jitLiteralOption)
        case Keys.jitFastMemory: return enabledDisabledString(for: jitFastMemoryOption)
        case Keys.dsiSD: return enabledDisabledString(for: dsiSDOption)
        case Keys.audioBitrate: return choiceValue(for: audioBitrateOption, choices: audioBitrateChoices)
        case Keys.audioInterpolation: return choiceValue(for: audioInterpolationOption, choices: audioInterpolationChoices)
        case Keys.firmwareLanguage:
            // When the user chose "Auto" (index 0), resolve from device locale at runtime
            let selected = valueForOption(firmwareLanguageOption).asInt ?? 0
            if selected == 0 {
                return CoreLocaleMapper.currentNDSLanguageString
            }
            return choiceValue(for: firmwareLanguageOption, choices: firmwareLanguageChoices)
        default:
            WLOG("Unsupported melonds option key: \(variable)")
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
