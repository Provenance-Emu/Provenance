import Foundation
import PVSupport
import PVCoreBridge

@objc public final class PVEmuThreeCoreOptions: NSObject, CoreOptions {
    
    static var resolutionOption: CoreOption {
        .enumeration(.init(title: "Resolution Upscaling",
                           description: nil,
                           requiresRestart: false),
                     values: [
                        .init(title: "1X", description: "1X", value: 1),
                        .init(title: "2X", description: "2X", value: 2),
                        .init(title: "3X", description: "3X", value: 3),
                        .init(title: "4X", description: "4X", value: 4),
                        .init(title: "5X", description: "5X", value: 5),
                        .init(title: "6X", description: "6X", value: 6),
                        .init(title: "7X", description: "7X", value: 7),
                        .init(title: "8X", description: "8X", value: 8),
                        .init(title: "9X", description: "9X", value: 9),
                        .init(title: "10X", description: "10X", value: 10),
                     ],
                     defaultValue: 1)
    }
    
    static var enableHLEOption: CoreOption {
        .bool(.init(
            title: "Enable High Level Emulation",
            description: nil,
            requiresRestart: true),
              defaultValue: true)
    }
    
    static var cpuClockOption: CoreOption {
        .enumeration(.init(title: "CPU Clock Speed",
                           description: "Underclocking can increase performance but may cause the game to freeze or increase load times. Overclocking may reduce in game lag but also might cause freezes",
                           requiresRestart: false),
                     values: [
                        .init(title: "Auto", description: "Automatic scaling based on scene demand (Experimental)", value: 0),
                        .init(title: "5%", description: "5%", value: 5),
                        .init(title: "10%", description: "10%", value: 10),
                        .init(title: "15%", description: "15%", value: 15),
                        .init(title: "20%", description: "20%", value: 20),
                        .init(title: "30%", description: "30%", value: 30),
                        .init(title: "40%", description: "40%", value: 40),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "60%", description: "60%", value: 60),
                        .init(title: "70%", description: "70%", value: 70),
                        .init(title: "80%", description: "80%", value: 80),
                        .init(title: "90%", description: "90%", value: 90),
                        .init(title: "100%", description: "100%", value: 100),
                        .init(title: "120%", description: "120%", value: 120),
                        .init(title: "150%", description: "150%", value: 150),
                        .init(title: "200%", description: "200%", value: 200),
                        .init(title: "300%", description: "300%", value: 300),
                        .init(title: "400%", description: "400%", value: 400),
                     ],
                     defaultValue: 100)
    }
    
    static var enableJITOption: CoreOption {
        .bool(.init(
            title: "Enable Just in Time",
            description: "Faster CPU, will Crash if not supported",
            requiresRestart: true),
              defaultValue: false)
    }
    
    static var enableLoggingOption: CoreOption {
        .bool(.init(
            title: "Enable Logging",
            description: "May affect performance",
            requiresRestart: true),
              defaultValue: false)
    }
    
    static var enableNew3DSOption: CoreOption {
        .bool(.init(
            title: "Enable New 3DS",
            description: nil,
            requiresRestart: false),
              defaultValue: true)
    }
    
    static var gsOption: CoreOption {
        .enumeration(.init(title: "Graphics Handler",
                           description: "(Requires Restart)",
                           requiresRestart: true),
                     values: [
                        .init(title: "Vulkan", description: "Vulkan", value: 0),
                     ],
                     defaultValue: 0)
    }
    
    static var enableAsyncShaderOption: CoreOption {
        .bool(.init(
            title: "Enable Async Shader Compilation",
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
    
    static var enableAsyncPresentOption: CoreOption {
        .bool(.init(
            title: "Enable Async Presentation",
            description: "Faster Input Responsiveness (Disable if the game crashes)",
            requiresRestart: false),
              defaultValue: true)
    }
    
    static var shaderTypeOption: CoreOption {
        .enumeration(.init(title: "Shader Acceleration / Graphic Accuracy",
                           description: nil,
                           requiresRestart: true),
                     values: [
                        .init(title: "None (Slow, but Accurate)", description: "None (Slow, but Accurate)", value: 1),
                        .init(title: "HW (Faster, Accurate Render)", description: "HW (Faster, Accurate Render)", value: 2),
                        .init(title: "HW Partial Render (Fastest, Inaccurate Render)", description: "HW Partial Render (Fastest, Inaccurate Render)", value: 3),
                        .init(title: "HW Full Render (Experimental)", description: "HW Full Render (Experimental)", value: 4),
                     ],
                     defaultValue: 2)
    }
    
    static var regionOption: CoreOption {
        .enumeration(.init(title: "System Region",
                           description: "The preferred language for multi-language supported games.",
                           requiresRestart: true),
                     values: [
                        .init(title: "Automatic", description: "Select based on local region.", value: -1),
                        .init(title: "Japan", description: "", value: 0),
                        .init(title: "USA", description: "", value: 1),
                        .init(title: "Europe", description: "", value: 2),
                        .init(title: "Australia", description: "", value: 2),
                        .init(title: "China", description: "", value: 3),
                        .init(title: "Korea", description: "", value: 4),
                        .init(title: "Taiwan", description: "", value: 5),

                     ],
                     defaultValue: -1)
    }
    
    static var enableVSyncOption: CoreOption {
        .bool(.init(
            title: "Enable VSync",
            description: nil,
            requiresRestart: true),
              defaultValue: true)
    }
    
    static var realtimeAudioOption: CoreOption {
        .bool(.init(
            title: "Realtime Audio",
            description: "Scales audio playback speed to account for drops in emulation framerate",
            requiresRestart: false),
              defaultValue: false)
    }
    
    static var enableShaderAccurateMulOption: CoreOption {
        .bool(.init(
            title: "Enable Shader Accurate Mul",
            description: "Some games require this to be enabled to render properly, but slightly reduces performance",
            requiresRestart: false),
              defaultValue: true)
    }
    
    static var enableShaderJITOption: CoreOption {
        .bool(.init(
            title: "Enable Shader Just in Time",
            description: nil,
            requiresRestart: false),
              defaultValue: true)
    }
    
    static var portraitTypeOption: CoreOption {
        .enumeration(.init(title: "Portrait Layout",
                           description: "",
                           requiresRestart: true),
                     values: [
                        .init(title: "Default", description: "Default", value: 0),
                        .init(title: "Single Screen", description: "Single Screen", value: 1),
                        .init(title: "Large Screen", description: "Large Screen", value: 2),
                        .init(title: "Side Screen", description: "Side Screen", value: 3),
                        .init(title: "Portrait", description: "Portrait", value: 5),
                        .init(title: "Landscape", description: "Landscape", value: 6)
                     ],
                     defaultValue: 5)
    }
    
    static var landscapeTypeOption: CoreOption {
        .enumeration(.init(title: "Landscape Layout",
                           description: "",
                           requiresRestart: true),
                     values: [
                        .init(title: "Default", description: "Default", value: 0),
                        .init(title: "Single Screen", description: "Single Screen", value: 1),
                        .init(title: "Large Screen", description: "Large Screen", value: 2),
                        .init(title: "Side Screen", description: "Side Screen", value: 3),
                        .init(title: "Portrait", description: "Portrait", value: 5),
                        .init(title: "Landscape", description: "Landscape", value: 6)
                     ],
                     defaultValue: 5)
    }
    
    static var stretchAudioOption: CoreOption {
        .bool(.init(
            title: "Stretch Audio",
            description: nil,
            requiresRestart: false),
              defaultValue: true)
    }
    
    static var volumeOption: CoreOption {
        .enumeration(.init(title: "Audio Volume",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "100%", description: "100%", value: 100),
                        .init(title: "90%", description: "90%", value: 90),
                        .init(title: "80%", description: "80%", value: 80),
                        .init(title: "70%", description: "70%", value: 70),
                        .init(title: "60%", description: "60%", value: 60),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "40%", description: "40%", value: 40),
                        .init(title: "30%", description: "30%", value: 30),
                        .init(title: "20%", description: "20%", value: 20),
                        .init(title: "10%", description: "10%", value: 10),
                        .init(title: "0%", description: "0%", value: 0),
                     ],
                     defaultValue: 100)
    }
    
    static var swapScreenOption: CoreOption {
        .bool(.init(
            title: "Swap Screen",
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
    
    static var uprightScreenOption: CoreOption {
        .bool(.init(
            title: "Upright Screen",
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
    
    static var customTexturesOption: CoreOption {
        .bool(.init(
            title: "Use Custom Textures",
            description: "Replace textures with PNG files. Textures are loaded from provenance/load/textures/[Title ID].",
            requiresRestart: false),
              defaultValue: false)
    }
    
    static var preloadTextuesOption: CoreOption {
        .bool(.init(
            title: "Preload Textures",
            description: nil,
            requiresRestart: false),
              defaultValue: true)
    }
    static var stereoRenderOption: CoreOption {
        .enumeration(.init(title: "3D Stereo Render",
                           description: "(Requires Restart)",
                           requiresRestart: true),
                     values: [
                        .init(title: "Off", description: "Off", value: 0),
                        .init(title: "Side By Side", description: "Side By Side", value: 1),
                        .init(title: "Anaglyph", description: "Anaglyph", value: 2),
                        .init(title: "Interlaced", description: "Interlaced", value: 3),
                        .init(title: "Reverse Interlaced", description: "Reverse Interlaced", value: 4),
                        .init(title: "Cardboard VR", description: "Cardboard VR", value: 5),
                     ],
                     defaultValue: 0)
    }
    
    /*
     Auto = 0,
     Null = 1,
     Static = 2,
     Cubeb = 3,
     OpenAL = 4,
     CoreAudio = 5,
     */
    static var inputTypeOption: CoreOption {
        .enumeration(.init(title: "Microphone Input",
                           description: "(Requires Restart)",
                           requiresRestart: true),
                     values: [
                        .init(title: "Auto", description: "Automatic best, first available input", value: 0),
                        .init(title: "None", description: "No input", value: 1),
                        .init(title: "Static", description: "Generates random static", value: 2),
                        .init(title: "OpenAL", description: "Use OpenAL microphonedriver", value: 4),
                        .init(title: "Core Audio", description: "Use CoreAudio microphone driver", value: 5),
                     ],
                     defaultValue: 0)
    }
    static var threedFactorOption: CoreOption {
        .enumeration(.init(title: "3D Factor",
                           description: "(Requires Restart)",
                           requiresRestart: true),
                     values: [
                        .init(title: "100%", description: "100%", value: 100),
                        .init(title: "90%", description: "90%", value: 90),
                        .init(title: "80%", description: "80%", value: 80),
                        .init(title: "70%", description: "70%", value: 70),
                        .init(title: "60%", description: "60%", value: 60),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "40%", description: "40%", value: 40),
                        .init(title: "30%", description: "30%", value: 30),
                        .init(title: "20%", description: "20%", value: 20),
                        .init(title: "10%", description: "10%", value: 10),
                     ],
                     defaultValue: 100)
    }
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [
            resolutionOption, enableHLEOption, cpuClockOption, enableJITOption, enableLoggingOption, enableNew3DSOption, gsOption, enableAsyncShaderOption, enableAsyncPresentOption,
            shaderTypeOption, enableVSyncOption, enableShaderAccurateMulOption, enableShaderJITOption, portraitTypeOption, landscapeTypeOption, inputTypeOption, volumeOption, realtimeAudioOption,
            stretchAudioOption, swapScreenOption, uprightScreenOption, regionOption, customTexturesOption, preloadTextuesOption, stereoRenderOption, threedFactorOption
        ]
        let coreGroup:CoreOption = .group(.init(title: "EmuThreeds Core",
                                                description: "Global options for EmuThreeds"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc
extension PVEmuThreeCoreOptions {
    @objc public static var resolution: String { valueForOption(PVEmuThreeCoreOptions.resolutionOption).asString }
    @objc public static var enableHLE: Bool { valueForOption(PVEmuThreeCoreOptions.enableHLEOption) }
    @objc public static var cpuClock: Int { valueForOption(PVEmuThreeCoreOptions.cpuClockOption)  }
    @objc public static var enableJIT: Bool { valueForOption(PVEmuThreeCoreOptions.enableJITOption) }
    @objc public static var enableLogging: Bool { valueForOption(PVEmuThreeCoreOptions.enableLoggingOption) }
    @objc public static var enableNew3DS: Bool { valueForOption(PVEmuThreeCoreOptions.enableNew3DSOption) }
    @objc public static var gs: Int { valueForOption(PVEmuThreeCoreOptions.gsOption)  }
    @objc public static var enableAsyncShader: Bool { valueForOption(PVEmuThreeCoreOptions.enableAsyncShaderOption) }
    @objc public static var enableAsyncPresent: Int { valueForOption(PVEmuThreeCoreOptions.enableAsyncPresentOption)  }
    @objc public static var shaderType: Int { valueForOption(PVEmuThreeCoreOptions.shaderTypeOption)  }
    @objc public static var region: Int { valueForOption(PVEmuThreeCoreOptions.regionOption)  }
    @objc public static var enableVSync: Bool { valueForOption(PVEmuThreeCoreOptions.enableVSyncOption) }
    @objc public static var realtimeAudio: Bool { valueForOption(PVEmuThreeCoreOptions.realtimeAudioOption) }
    @objc public static var enableShaderAccurateMul: Bool { valueForOption(PVEmuThreeCoreOptions.enableShaderAccurateMulOption) }
    @objc public static var enableShaderJIT: Bool { valueForOption(PVEmuThreeCoreOptions.enableShaderJITOption) }
    @objc public static var inputType: Int { valueForOption(PVEmuThreeCoreOptions.inputTypeOption) }

     // TODO: Finish this with the rest of the options if wanted
}

@objc public extension PVEmuThreeCoreBridge {
    
    func parseOptions() {
        self.gsPreference = NSNumber(value: PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.gsOption).asInt ?? 0).int8Value
        self.resFactor = NSNumber(value: PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.resolutionOption).asInt ?? 1).int8Value
        self.enableHLE = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableHLEOption).asBool
        self.cpuOClock = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.cpuClockOption).asInt ?? 100).int8Value
        self.enableJIT = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableJITOption).asBool
        self.enableLogging = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableLoggingOption).asBool
        self.useNew3DS =
        PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableNew3DSOption).asBool
        self.asyncShader = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableAsyncShaderOption).asBool
        self.asyncPresent = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableAsyncPresentOption).asBool
        self.shaderType = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.shaderTypeOption).asInt ?? 2).int8Value
        self.region = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.regionOption).asInt ?? -1).int8Value
        self.enableVSync = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableVSyncOption).asBool
        self.enableShaderAccurate = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableShaderAccurateMulOption).asBool
        self.enableShaderJIT = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.enableShaderJITOption).asBool
        self.portraitType = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.portraitTypeOption).asInt ?? 5).int8Value
        self.landscapeType = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.landscapeTypeOption).asInt ?? 5).int8Value
        self.stretchAudio = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.stretchAudioOption).asBool
        self.inputType = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.inputTypeOption).asInt ?? 5).int8Value
        self.volume = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.volumeOption).asInt ?? 100).int8Value
        self.swapScreen = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.swapScreenOption).asBool
        self.uprightScreen = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.uprightScreenOption).asBool
        self.preloadTextures = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.preloadTextuesOption).asBool
        self.customTextures = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.customTexturesOption).asBool
        self.stereoRender = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.stereoRenderOption).asInt ?? 0).int8Value
        self.threedFactor = NSNumber(value:PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.threedFactorOption).asInt ?? 100).int8Value
        self.realtimeAudio = PVEmuThreeCoreOptions.valueForOption(PVEmuThreeCoreOptions.realtimeAudioOption).asBool
    }
}
