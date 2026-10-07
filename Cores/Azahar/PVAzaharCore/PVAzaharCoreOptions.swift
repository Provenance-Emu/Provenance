import Foundation
import PVCoreBridge
import PVSupport

/// Option definitions for the Azahar 3DS core. Enumeration values are the raw numbers the bridge expects
/// (`Settings::TextureFilter` 0...5, layout UI indices 0...4, region -1 = auto).
@objc public final class PVAzaharCoreOptions: NSObject, CoreOptions {
    // MARK: Graphics
    static var resolutionOption: CoreOption {
        .enumeration(.init(title: "Resolution Upscaling", description: "Internal render scale. Higher costs GPU time.", requiresRestart: true),
                     values: (1...6).map { .init(title: "\($0)X", description: nil, value: $0) }, defaultValue: 1)
    }
    static var layoutOption: CoreOption {
        .enumeration(.init(title: "Screen Layout", description: nil, requiresRestart: false),
                     values: [
                        .init(title: "Default (stacked)", description: nil, value: 0),
                        .init(title: "Single Screen", description: nil, value: 1),
                        .init(title: "Large Screen", description: nil, value: 2),
                        .init(title: "Side by Side", description: nil, value: 3),
                        .init(title: "Hybrid", description: nil, value: 4)
                     ], defaultValue: 0)
    }
    static var swapScreensOption: CoreOption {
        .bool(.init(title: "Swap Screens", description: nil, requiresRestart: false), defaultValue: false)
    }
    static var hardwareShaderOption: CoreOption {
        .bool(.init(title: "Hardware Shader", description: "GPU vertex/geometry shaders. Disable only for debugging.", requiresRestart: true), defaultValue: true)
    }
    static var accurateMulOption: CoreOption {
        .bool(.init(title: "Accurate Multiplication", description: "Fixes lighting glitches in some games at a small cost.", requiresRestart: true), defaultValue: true)
    }
    static var asyncShaderOption: CoreOption {
        .bool(.init(title: "Async Shader Compilation", description: "Avoids stutter while shaders compile; may show brief missing geometry.", requiresRestart: true), defaultValue: true)
    }
    static var asyncPresentOption: CoreOption {
        .bool(.init(title: "Async Presentation", description: nil, requiresRestart: true), defaultValue: true)
    }
    static var diskShaderCacheOption: CoreOption {
        .bool(.init(title: "Disk Shader Cache", description: nil, requiresRestart: true), defaultValue: true)
    }
    static var textureFilterOption: CoreOption {
        .enumeration(.init(title: "Texture Filter", description: nil, requiresRestart: true),
                     values: [
                        .init(title: "None", description: nil, value: 0),
                        .init(title: "Anime4K", description: nil, value: 1),
                        .init(title: "Bicubic", description: nil, value: 2),
                        .init(title: "ScaleForce", description: nil, value: 3),
                        .init(title: "xBRZ", description: nil, value: 4),
                        .init(title: "MMPX", description: nil, value: 5)
                     ], defaultValue: 0)
    }

    // MARK: System
    static var new3DSOption: CoreOption {
        .bool(.init(title: "New 3DS Mode", description: "Extra CPU cores and memory. Required by some games.", requiresRestart: true), defaultValue: true)
    }
    static var cpuClockOption: CoreOption {
        .enumeration(.init(title: "CPU Clock", description: "Below 100% speeds up some games; above 100% can reduce lag or break games.", requiresRestart: false),
                     values: [25, 50, 75, 100, 125, 150, 200, 300, 400].map { .init(title: "\($0)%", description: nil, value: $0) }, defaultValue: 100)
    }
    static var regionOption: CoreOption {
        .enumeration(.init(title: "Region", description: nil, requiresRestart: true),
                     values: [
                        .init(title: "Auto", description: nil, value: -1), .init(title: "Japan", description: nil, value: 0),
                        .init(title: "USA", description: nil, value: 1), .init(title: "Europe", description: nil, value: 2),
                        .init(title: "Australia", description: nil, value: 3), .init(title: "China", description: nil, value: 4),
                        .init(title: "Korea", description: nil, value: 5), .init(title: "Taiwan", description: nil, value: 6)
                     ], defaultValue: -1)
    }
    static let unlimitedSpeedPercent = 1000
    static var frameLimitOption: CoreOption {
        .enumeration(.init(title: "Speed Limit", description: nil, requiresRestart: false),
                     values: [50, 100, 150, 200, unlimitedSpeedPercent].map {
                         .init(title: $0 == unlimitedSpeedPercent ? "Unlimited" : "\($0)%", description: nil, value: $0)
                     }, defaultValue: 100)
    }

    // MARK: Audio
    static var audioStretchOption: CoreOption {
        .bool(.init(title: "Audio Stretching", description: "Keeps audio smooth when the game runs slow.", requiresRestart: true), defaultValue: true)
    }
    static var realtimeAudioOption: CoreOption {
        .bool(.init(title: "Realtime Audio", description: "Lower latency; may crackle on slow devices.", requiresRestart: true), defaultValue: true)
    }

    public static var options: [CoreOption] {
        [.group(.init(title: "Graphics", description: nil), subOptions: [
            resolutionOption, layoutOption, swapScreensOption, textureFilterOption, hardwareShaderOption,
            accurateMulOption, asyncShaderOption, asyncPresentOption, diskShaderCacheOption]),
         .group(.init(title: "System", description: nil), subOptions: [new3DSOption, cpuClockOption, regionOption, frameLimitOption]),
         .group(.init(title: "Audio", description: nil), subOptions: [audioStretchOption, realtimeAudioOption])]
    }

    /// Copies the stored option values into the bridge. Call before `loadFile`.
    @objc public static func apply(to bridge: PVAzaharCoreBridge) {
        func int(_ option: CoreOption) -> Int { PVAzaharCore.valueForOption(option) }
        func bool(_ option: CoreOption) -> Bool { PVAzaharCore.valueForOption(option) }
        bridge.resolutionFactor = int(resolutionOption)
        bridge.layoutOption = int(layoutOption)
        bridge.swapScreens = bool(swapScreensOption)
        bridge.hardwareShader = bool(hardwareShaderOption)
        bridge.accurateMultiplication = bool(accurateMulOption)
        bridge.asyncShaderCompilation = bool(asyncShaderOption)
        bridge.asyncPresentation = bool(asyncPresentOption)
        bridge.diskShaderCache = bool(diskShaderCacheOption)
        bridge.textureFilter = int(textureFilterOption)
        bridge.new3DSMode = bool(new3DSOption)
        bridge.cpuClockPercent = int(cpuClockOption)
        bridge.regionValue = int(regionOption)
        bridge.frameLimitPercent = int(frameLimitOption)
        bridge.audioStretching = bool(audioStretchOption)
        bridge.realtimeAudio = bool(realtimeAudioOption)
    }
}
