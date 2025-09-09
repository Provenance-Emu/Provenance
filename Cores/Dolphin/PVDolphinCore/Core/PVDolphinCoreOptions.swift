import Foundation
import PVSupport
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

@objc
public class PVDolphinCoreOptions: NSObject, CoreOptions {

    // MARK: - Graphics Settings

	 static var resolutionOption: CoreOption = {
		  .enumeration(.init(title: "Internal Resolution",
				description: "Controls rendering resolution. Higher values improve visual quality but increase GPU load.",
				requiresRestart: true),
			values: [
				.init(title: "1X Native", description: "1X", value: 1),
				.init(title: "2X Native", description: "2X", value: 2),
				.init(title: "3X Native", description: "3X", value: 3),
				.init(title: "4X Native", description: "4X", value: 4),
				.init(title: "5X Native", description: "5X", value: 5),
				.init(title: "6X Native", description: "6X", value: 6),
			],
			defaultValue: 1)
			}()

	static var gsOption: CoreOption = {
		 .enumeration(.init(title: "Graphics Backend",
			   description: "Graphics API to use. Metal recommended on iOS.",
			   requiresRestart: true),
		  values: [
			   .init(title: "Vulkan", description: "Vulkan", value: 0),
			   .init(title: "OpenGL", description: "OpenGL", value: 1),
			   .init(title: "Metal", description: "Metal (Recommended)", value: 2)
		  ],
		  defaultValue: 2)
	}()

    static var aspectRatioOption: CoreOption = {
        .enumeration(.init(title: "Aspect Ratio",
                          description: "Aspect ratio for rendering",
                          requiresRestart: false),
                    values: [
                        .init(title: "Auto", description: "Auto", value: 0),
                        .init(title: "Force 4:3", description: "Force 4:3", value: 1),
                        .init(title: "Force 16:9", description: "Force 16:9", value: 2),
                        .init(title: "Stretch to Window", description: "Stretch to Window", value: 3)
                    ],
                    defaultValue: 0)
    }()

    static var vsyncOption: CoreOption = {
        .bool(.init(
            title: "V-Sync",
            description: "Wait for vertical blanks to prevent tearing. May decrease performance.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var anisotropicFilteringOption: CoreOption = {
        .enumeration(.init(title: "Anisotropic Filtering",
                          description: "Enhances texture quality at oblique viewing angles",
                          requiresRestart: false),
                    values: [
                        .init(title: "Default", description: "Default", value: 0),
                        .init(title: "2x", description: "2x", value: 1),
                        .init(title: "4x", description: "4x", value: 2),
                        .init(title: "8x", description: "8x", value: 3),
                        .init(title: "16x", description: "16x", value: 4)
                    ],
                    defaultValue: 0)
    }()

	static var forceBilinearFilteringOption: CoreOption = {
		.bool(.init(
			title: "Enable bilinear filtering.",
			description: nil,
			requiresRestart: true),
		defaultValue: false)
	}()

    static var showFPSOption: CoreOption = {
        .bool(.init(
            title: "Show FPS Counter",
            description: "Display frames per second counter on screen.",
            requiresRestart: false),
        defaultValue: false)
    }()

    // MARK: - Graphics Enhancements

    static var scaledEFBCopyOption: CoreOption = {
        .bool(.init(
            title: "Scaled EFB Copy",
            description: "Greatly increases quality of render-to-texture effects. Slightly increases GPU load.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var disableFogOption: CoreOption = {
        .bool(.init(
            title: "Disable Fog",
            description: "Makes distant objects more visible by removing fog. May break some games.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var pixelLightingOption: CoreOption = {
        .bool(.init(
            title: "Per-Pixel Lighting",
            description: "Calculates lighting per-pixel rather than per-vertex for smoother appearance.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var forceTrueColorOption: CoreOption = {
        .bool(.init(
            title: "Force 24-bit Color",
            description: "Forces 24-bit RGB rendering to reduce color banding.",
            requiresRestart: false),
        defaultValue: true)
    }()

    // MARK: - Graphics Hacks (DolphinQt Parity)

    static var skipEFBAccessFromCPUOption: CoreOption = {
        .bool(.init(
            title: "Skip EFB Access from CPU",
            description: "Disables EFB access from CPU for speed, but may break some games.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var ignoreFormatChangesOption: CoreOption = {
        .bool(.init(
            title: "Ignore Format Changes",
            description: "Ignores EFB format changes for speed, but may cause graphical glitches.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var storeEFBCopiesToTextureOnlyOption: CoreOption = {
        .bool(.init(
            title: "Store EFB Copies to Texture Only",
            description: "Stores EFB copies only to texture, not RAM. Faster but less accurate.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var deferEFBCopiesOption: CoreOption = {
        .bool(.init(
            title: "Defer EFB Copies",
            description: "Defers EFB copies for performance. May cause issues in some games.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var textureCacheAccuracyOption: CoreOption = {
        .enumeration(.init(title: "Texture Cache Accuracy",
                          description: "Controls accuracy of the texture cache. Higher values are more accurate but slower.",
                          requiresRestart: false),
                    values: [
                        .init(title: "Safe", description: "Most accurate, slowest", value: 0),
                        .init(title: "Medium", description: "Balanced accuracy/performance", value: 1),
                        .init(title: "Fast", description: "Least accurate, fastest", value: 2)
                    ],
                    defaultValue: 1)
    }()

    static var storeXFBCopiesToTextureOnlyOption: CoreOption = {
        .bool(.init(
            title: "Store XFB Copies to Texture Only",
            description: "Stores XFB copies only to texture, not RAM. Faster but less accurate.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var immediateXFBOption: CoreOption = {
        .bool(.init(
            title: "Immediate XFB",
            description: "Presents XFB copies immediately. May improve performance but can cause issues.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var skipDuplicateXFBsOption: CoreOption = {
        .bool(.init(
            title: "Skip Presenting Duplicate Frames",
            description: "Skips presenting duplicate XFB frames. Required for VI skip.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var gpuTextureDecodingOption: CoreOption = {
        .bool(.init(
            title: "GPU Texture Decoding",
            description: "Use GPU for texture decoding. Faster but may be less accurate.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var fastDepthCalculationOption: CoreOption = {
        .bool(.init(
            title: "Fast Depth Calculation",
            description: "Enables fast depth calculation for performance. May cause graphical issues.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var disableBoundingBoxOption: CoreOption = {
        .bool(.init(
            title: "Disable Bounding Box",
            description: "Disables bounding box emulation. May improve performance but breaks some games.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var saveTextureCacheToStateOption: CoreOption = {
        .bool(.init(
            title: "Save Texture Cache to State",
            description: "Saves texture cache to save states. May improve save state accuracy but increase size.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var vertexRoundingOption: CoreOption = {
        .bool(.init(
            title: "Vertex Rounding",
            description: "Enables vertex rounding for improved accuracy in some games.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var viSkipOption: CoreOption = {
        .bool(.init(
            title: "VI Skip",
            description: "Skips VI updates for performance. May cause issues in some games.",
            requiresRestart: false),
        defaultValue: false)
    }()

    // MARK: - Shader Settings

    static var shaderCompilationModeOption: CoreOption = {
        .enumeration(.init(title: "Shader Compilation",
                          description: "How shaders are compiled and cached",
                          requiresRestart: false),
                    values: [
                        .init(title: "Specialized (Default)", description: "Synchronous", value: 0),
                        .init(title: "Exclusive Ubershaders", description: "Synchronous Ubershaders", value: 1),
                        .init(title: "Hybrid Ubershaders", description: "Asynchronous Ubershaders", value: 2),
                        .init(titlee: "Skip Drawing", description: "Asynchronous Skip Rendering", value: 3)
                    ],
                    defaultValue: 0)
    }()

    static var waitForShadersOption: CoreOption = {
        .bool(.init(
            title: "Wait for Shaders",
            description: "Wait for all shaders to compile before starting. Reduces stuttering.",
            requiresRestart: false),
        defaultValue: false)
    }()

    // MARK: - CPU/Emulation Settings

    static var enableCheatOption: CoreOption = {
        .bool(.init(
            title: "Enable Cheat Codes",
            description: "Enable cheat code support. May reduce performance.",
            requiresRestart: true),
        defaultValue: false)
    }()

	static var msaaOption: CoreOption = {
		 .enumeration(.init(title: "Multi Surface Anti-Aliasing",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "1X", description: "1X", value: 1),
			   .init(title: "2X", description: "2X", value: 2),
			   .init(title: "4X", description: "4X", value: 4),
			   .init(title: "8X", description: "8X", value: 8),
		   ],
		   defaultValue: 1)
		   }()

	static var ssaaOption: CoreOption = {
		.bool(.init(
			title: "Single Surface Anti-Aliasing",
			description: nil,
			requiresRestart: false),
		defaultValue: false)
	}()

	static var fastMemoryOption: CoreOption = {
		.bool(.init(
			title: "Fast Memory (Much Faster)",
			description: nil,
			requiresRestart: true),
		defaultValue: true)
	}()

	static var cpuOption: CoreOption = {
		 .enumeration(.init(title: "CPU Emulation Engine",
			   description: "CPU emulation method. JIT provides best performance.",
			   requiresRestart: true),
		  values: [
			.init(title: "Interpreter", description: "Interpreter (Slowest, Most Compatible)", value: 0),
			.init(title: "Cached Interpreter", description: "Cached Interpreter (Balanced)", value: 1),
			.init(title: "JIT Recompiler", description: "JIT (Fastest)", value: 2)
		  ],
		  defaultValue: 1)
	}()

	static var cpuClockOption: CoreOption = {
	.enumeration(.init(title: "CPU Clock Override",
		  description: "Adjust emulated CPU speed. Lower values reduce performance but save battery/heat. Higher values may improve performance in CPU-limited games.",
		  requiresRestart: true),
	  values: [
		  .init(title: "25% (Very Slow)", description: "0.25X", value: 25),
		  .init(title: "33% (Slow)", description: "0.33X", value: 33),
		  .init(title: "50% (Half Speed)", description: "0.5X", value: 50),
		  .init(title: "66% (Reduced)", description: "0.66X", value: 66),
		  .init(title: "75% (Lower)", description: "0.75X", value: 75),
		  .init(title: "85% (Slightly Lower)", description: "0.85X", value: 85),
		  .init(title: "90% (Slightly Reduced)", description: "0.9X", value: 90),
		  .init(title: "100% (Default)", description: "1X", value: 100),
		  .init(title: "150% (Faster)", description: "1.5X", value: 150),
		  .init(title: "200% (Double)", description: "2X", value: 200),
		  .init(title: "300% (Triple)", description: "3X", value: 300),
		  .init(title: "400% (Quad)", description: "4X", value: 400),
	  ],
	  defaultValue: 100)
	  }()

    static var dualCoreOption: CoreOption = {
        .bool(.init(
            title: "Dual Core",
            description: "Enables dual-core emulation for better performance. May cause issues in some games.",
            requiresRestart: true),
        defaultValue: true)
    }()

    static var idleSkippingOption: CoreOption = {
        .bool(.init(
            title: "Idle Skipping",
            description: "Skip idle loops to improve performance.",
            requiresRestart: false),
        defaultValue: true)
    }()

    // MARK: - Advanced Emulation Settings

    static var enableVBIOverrideOption: CoreOption = {
        .bool(.init(
            title: "Enable VBI Frequency Override",
            description: "Override vertical blanking interval frequency for performance tuning.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var vbiFrequencyRangeOption: CoreOption = {
        .rangef(.init(title: "VBI Frequency Override",
                     description: "Custom VBI frequency as percentage (4%-501%). Higher values may improve performance but can cause timing issues.",
                     requiresRestart: false),
               range: CoreOptionRange<Float>(defaultValue: 100.0, min: 4.0, max: 501.0),
               defaultValue: 100.0)
    }()

    static var enableMMUOption: CoreOption = {
        .bool(.init(
            title: "Enable MMU",
            description: "Enable Memory Management Unit. Improves compatibility but reduces performance significantly.",
            requiresRestart: true),
        defaultValue: false)
    }()

    static var pauseOnPanicOption: CoreOption = {
        .bool(.init(
            title: "Pause on Panic",
            description: "Pause emulation when a panic occurs instead of stopping.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var enableWriteBackCacheOption: CoreOption = {
        .bool(.init(
            title: "Enable Write-Back Cache",
            description: "Enable write-back cache emulation. More accurate but significantly slower.",
            requiresRestart: true),
        defaultValue: false)
    }()

    static var speedLimitOption: CoreOption = {
        .enumeration(.init(title: "Speed Limit",
                          description: "Limit emulation speed as percentage of normal speed.",
                          requiresRestart: false),
                    values: [
                        .init(title: "Unlimited", description: "No Limit", value: 0),
                        .init(title: "10%", description: "10%", value: 10),
                        .init(title: "25%", description: "25%", value: 25),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "75%", description: "75%", value: 75),
                        .init(title: "100% (Normal)", description: "100%", value: 100),
                        .init(title: "125%", description: "125%", value: 125),
                        .init(title: "150%", description: "150%", value: 150),
                        .init(title: "200%", description: "200%", value: 200)
                    ],
                    defaultValue: 100)
    }()

    static var fallbackRegionOption: CoreOption = {
        .enumeration(.init(title: "Fallback Region",
                          description: "Region to use when game region cannot be determined.",
                          requiresRestart: false),
                    values: [
                        .init(title: "NTSC-U (USA)", description: "NTSC-U", value: 0),
                        .init(title: "NTSC-J (Japan)", description: "NTSC-J", value: 1),
                        .init(title: "PAL (Europe)", description: "PAL", value: 2),
                        .init(title: "NTSC-K (Korea)", description: "NTSC-K", value: 4)
                    ],
                    defaultValue: 0)
    }()
    // MARK: - Audio Settings

    static var audioBackendOption: CoreOption = {
        .enumeration(.init(title: "Audio Backend",
                          description: "Audio output method",
                          requiresRestart: true),
                    values: [
                        .init(title: "Cubeb", description: "Cubeb (Recommended)", value: 0),
                        .init(title: "OpenAL", description: "OpenAL", value: 1),
                        .init(title: "Null", description: "No Audio", value: 2)
                    ],
                    defaultValue: 0)
    }()

    static var audioStretchOption: CoreOption = {
        .bool(.init(
            title: "Audio Stretching",
            description: "Stretch audio to prevent crackling when emulation is slow.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var volumeOption: CoreOption = {
        .enumeration(.init(title: "Audio Volume",
                           description: "Master audio volume level",
                           requiresRestart: false),
                     values: [
                        .init(title: "100%", description: "100%", value: 100),
                        .init(title: "75%", description: "75%", value: 75),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "25%", description: "25%", value: 25),
                        .init(title: "0% (Mute)", description: "0%", value: 0),
                     ],
                     defaultValue: 100)
    }()

    // MARK: - GameCube/Wii Settings

    static var multiPlayerOption: CoreOption = {
        .bool(.init(
            title: MAP_MULTIPLAYER,
            description: "Enable multiplayer controller support",
            requiresRestart: false),
              defaultValue: false)
    }()

    static var skipIPLOption: CoreOption = {
        .bool(.init(
            title: "Skip GameCube BIOS",
            description: "Skip GameCube IPL/BIOS and boot games directly.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var wiiLanguageOption: CoreOption = {
        .enumeration(.init(title: "Wii System Language",
                          description: "System language for Wii games",
                          requiresRestart: false),
                    values: [
                        .init(title: "Japanese", description: "Japanese", value: 0),
                        .init(title: "English", description: "English", value: 1),
                        .init(title: "German", description: "German", value: 2),
                        .init(title: "French", description: "French", value: 3),
                        .init(title: "Spanish", description: "Spanish", value: 4),
                        .init(title: "Italian", description: "Italian", value: 5),
                        .init(title: "Dutch", description: "Dutch", value: 6),
                        .init(title: "Korean", description: "Korean", value: 9)
                    ],
                    defaultValue: 1)
    }()

    static var enableLoggingOption: CoreOption = {
        .bool(.init(
            title: "Enable Debug Logging",
            description: "Enable detailed logging for debugging. May impact performance.",
            requiresRestart: false),
        defaultValue: false)
    }()
	public static var options: [CoreOption] {
		var options = [CoreOption]()

        // Graphics Settings Group
		let graphicsOptions: [CoreOption] = [
			gsOption, resolutionOption, aspectRatioOption, vsyncOption,
            anisotropicFilteringOption, forceBilinearFilteringOption, showFPSOption
        ]
		let graphicsGroup: CoreOption = .group(.init(title: "Graphics",
												description: "Graphics rendering and display settings"),
										  subOptions: graphicsOptions)

        // Graphics Enhancements Group
        let enhancementOptions: [CoreOption] = [
            scaledEFBCopyOption, disableFogOption, pixelLightingOption,
            forceTrueColorOption
        ]
        let enhancementGroup: CoreOption = .group(.init(title: "Graphics Enhancements",
                                                       description: "Visual enhancement options"),
                                                 subOptions: enhancementOptions)

        // Anti-Aliasing Group
        let aaOptions: [CoreOption] = [
            msaaOption, ssaaOption
        ]
        let aaGroup: CoreOption = .group(.init(title: "Anti-Aliasing",
                                              description: "Anti-aliasing and smoothing options"),
                                        subOptions: aaOptions)

        // Shader Settings Group
        let shaderOptions: [CoreOption] = [
            shaderCompilationModeOption, waitForShadersOption
        ]
        let shaderGroup: CoreOption = .group(.init(title: "Shaders",
                                                  description: "Shader compilation and caching settings"),
                                            subOptions: shaderOptions)

        // CPU/Emulation Settings Group
        let cpuOptions: [CoreOption] = [
            cpuOption, cpuClockOption, dualCoreOption, idleSkippingOption,
            fastMemoryOption, enableCheatOption, enableVBIOverrideOption,
            vbiFrequencyRangeOption, enableMMUOption, pauseOnPanicOption,
            enableWriteBackCacheOption, speedLimitOption, fallbackRegionOption
        ]
        let cpuGroup: CoreOption = .group(.init(title: "CPU & Emulation",
                                               description: "CPU emulation and performance settings"),
                                         subOptions: cpuOptions)

        // Audio Settings Group
        let audioOptions: [CoreOption] = [
            audioBackendOption, audioStretchOption, volumeOption
        ]
        let audioGroup: CoreOption = .group(.init(title: "Audio",
                                                 description: "Audio output and volume settings"),
                                           subOptions: audioOptions)

        // Graphics Hacks Group
        let hacksOptions: [CoreOption] = [
            skipEFBAccessFromCPUOption,
            ignoreFormatChangesOption,
            storeEFBCopiesToTextureOnlyOption,
            deferEFBCopiesOption,
            textureCacheAccuracyOption,
            storeXFBCopiesToTextureOnlyOption,
            immediateXFBOption,
            skipDuplicateXFBsOption,
            gpuTextureDecodingOption,
            fastDepthCalculationOption,
            disableBoundingBoxOption,
            saveTextureCacheToStateOption,
            vertexRoundingOption,
            viSkipOption
        ]
        let hacksGroup: CoreOption = .group(.init(title: "Graphics Hacks",
                                                description: "Advanced graphics hacks for performance and compatibility. Change with caution."),
                                          subOptions: hacksOptions)

        // System Settings Group
        let systemOptions: [CoreOption] = [
            skipIPLOption, wiiLanguageOption, multiPlayerOption, enableLoggingOption
        ]
        let systemGroup: CoreOption = .group(.init(title: "System",
                                                  description: "GameCube and Wii system settings"),
                                            subOptions: systemOptions)

		options.append(contentsOf: [graphicsGroup, enhancementGroup, hacksGroup, aaGroup, shaderGroup, cpuGroup, audioGroup, systemGroup])
		return options
	}
}

@objc public extension PVDolphinCoreOptions {
    // MARK: - Graphics Settings

	@objc static var resolution: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.resolutionOption).asInt ?? 0
	}
	@objc static var gs: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.gsOption).asInt ?? 0
	}
    @objc static var aspectRatio: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.aspectRatioOption).asInt ?? 0
    }
    @objc static var vsync: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.vsyncOption).asBool
    }
    @objc static var anisotropicFiltering: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.anisotropicFilteringOption).asInt ?? 0
    }
	@objc static var bilinearFiltering: Bool {
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.forceBilinearFilteringOption).asBool
	}
    @objc static var showFPS: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.showFPSOption).asBool
    }

    // MARK: - Graphics Enhancements

    @objc static var scaledEFBCopy: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.scaledEFBCopyOption).asBool
    }
    @objc static var disableFog: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.disableFogOption).asBool
    }
    @objc static var pixelLighting: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.pixelLightingOption).asBool
    }
    @objc static var forceTrueColor: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.forceTrueColorOption).asBool
    }

    // MARK: - Graphics Hacks (DolphinQt Parity)

    @objc static var skipEFBAccessFromCPU: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.skipEFBAccessFromCPUOption).asBool
    }
    @objc static var ignoreFormatChanges: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.ignoreFormatChangesOption).asBool
    }
    @objc static var storeEFBCopiesToTextureOnly: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.storeEFBCopiesToTextureOnlyOption).asBool
    }
    @objc static var deferEFBCopies: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.deferEFBCopiesOption).asBool
    }
    @objc static var textureCacheAccuracy: Int {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.textureCacheAccuracyOption).asInt ?? 1
    }
    @objc static var storeXFBCopiesToTextureOnly: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.storeXFBCopiesToTextureOnlyOption).asBool
    }
    @objc static var immediateXFB: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.immediateXFBOption).asBool
    }
    @objc static var skipDuplicateXFBs: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.skipDuplicateXFBsOption).asBool
    }
    @objc static var gpuTextureDecoding: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.gpuTextureDecodingOption).asBool
    }
    @objc static var fastDepthCalculation: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastDepthCalculationOption).asBool
    }
    @objc static var disableBoundingBox: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.disableBoundingBoxOption).asBool
    }
    @objc static var saveTextureCacheToState: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.saveTextureCacheToStateOption).asBool
    }
    @objc static var vertexRounding: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.vertexRoundingOption).asBool
    }
    @objc static var viSkip: Bool {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.viSkipOption).asBool
    }

    // MARK: - Shader Settings

    @objc static var shaderCompilationMode: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.shaderCompilationModeOption).asInt ?? 0
    }
    @objc static var waitForShaders: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.waitForShadersOption).asBool
    }

    // MARK: - Anti-Aliasing

	@objc static var msaa: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.msaaOption).asInt ?? 0
	}
	@objc static var ssaa: Bool{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.ssaaOption).asBool
	}

    // MARK: - CPU/Emulation Settings

	@objc static var cpu: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.cpuOption).asInt ?? 0
	}
	@objc static var cpuClock: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.cpuClockOption).asInt ?? 0
	}
    @objc static var dualCore: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.dualCoreOption).asBool
    }
    @objc static var idleSkipping: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.idleSkippingOption).asBool
    }
	@objc static var fastMemory: Bool{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastMemoryOption).asBool
	}
    @objc static var enableCheat: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableCheatOption).asBool
    }

    // MARK: - Advanced Emulation Settings

    @objc static var enableVBIOverride: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableVBIOverrideOption).asBool
    }
    @objc static var vbiFrequencyRange: Float{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.vbiFrequencyRangeOption).asFloat ?? 100.0
    }
    @objc static var enableMMU: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableMMUOption).asBool
    }
    @objc static var pauseOnPanic: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.pauseOnPanicOption).asBool
    }
    @objc static var enableWriteBackCache: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableWriteBackCacheOption).asBool
    }
    @objc static var speedLimit: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.speedLimitOption).asInt ?? 100
    }
    @objc static var fallbackRegion: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.fallbackRegionOption).asInt ?? 0
    }

    // MARK: - Audio Settings

    @objc static var audioBackend: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.audioBackendOption).asInt ?? 0
    }
    @objc static var audioStretch: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.audioStretchOption).asBool
    }
    @objc static var volume: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.volumeOption).asInt ?? 100
    }

    // MARK: - System Settings

    @objc static var skipIPL: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.skipIPLOption).asBool
    }
    @objc static var wiiLanguage: Int{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.wiiLanguageOption).asInt ?? 1
    }
    @objc static var multiPlayer: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.multiPlayerOption).asBool
    }
    @objc static var enableLogging: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableLoggingOption).asBool
    }
}

@objc public extension PVDolphinCoreBridge {
    @objc func parseOptions() {
        // Graphics Settings
        self.gsPreference = NSNumber(value: PVDolphinCoreOptions.gs).int8Value
        self.resFactor = NSNumber(value: PVDolphinCoreOptions.resolution).int8Value
        self.aspectRatio = NSNumber(value: PVDolphinCoreOptions.aspectRatio).int8Value
        self.vsync = PVDolphinCoreOptions.vsync
        self.anisotropicFiltering = NSNumber(value: PVDolphinCoreOptions.anisotropicFiltering).int8Value
        self.isBilinear = PVDolphinCoreOptions.bilinearFiltering
        self.showFPS = PVDolphinCoreOptions.showFPS

        // Graphics Enhancements
        self.scaledEFBCopy = PVDolphinCoreOptions.scaledEFBCopy
        self.disableFog = PVDolphinCoreOptions.disableFog
        self.pixelLighting = PVDolphinCoreOptions.pixelLighting
        self.forceTrueColor = PVDolphinCoreOptions.forceTrueColor

        // Shader Settings
        self.shaderCompilationMode = NSNumber(value: PVDolphinCoreOptions.shaderCompilationMode).int8Value
        self.waitForShaders = PVDolphinCoreOptions.waitForShaders

        // Anti-Aliasing
        self.msaa = NSNumber(value: PVDolphinCoreOptions.msaa).int8Value
        self.ssaa = PVDolphinCoreOptions.ssaa
        if self.msaa < 2 {
            self.ssaa = false
        }

        // CPU/Emulation Settings
        self.cpuType = NSNumber(value: PVDolphinCoreOptions.cpu).int8Value
        self.cpuOClock = NSNumber(value: PVDolphinCoreOptions.cpuClock).int8Value
        self.dualCore = PVDolphinCoreOptions.dualCore
        self.idleSkipping = PVDolphinCoreOptions.idleSkipping
        self.fastMemory = PVDolphinCoreOptions.fastMemory
        self.enableCheatCode = PVDolphinCoreOptions.enableCheat

        // Advanced Emulation Settings
        self.enableVBIOverride = PVDolphinCoreOptions.enableVBIOverride
        self.vbiFrequencyRange = PVDolphinCoreOptions.vbiFrequencyRange
        self.enableMMU = PVDolphinCoreOptions.enableMMU
        self.pauseOnPanic = PVDolphinCoreOptions.pauseOnPanic
        self.enableWriteBackCache = PVDolphinCoreOptions.enableWriteBackCache
        self.speedLimit = NSNumber(value: PVDolphinCoreOptions.speedLimit).int8Value
        self.fallbackRegion = NSNumber(value: PVDolphinCoreOptions.fallbackRegion).int8Value

        // Audio Settings
        self.audioBackend = NSNumber(value: PVDolphinCoreOptions.audioBackend).int8Value
        self.audioStretch = PVDolphinCoreOptions.audioStretch
        self.volume = NSNumber(value: PVDolphinCoreOptions.volume).int8Value

        // System Settings
        self.skipIPL = PVDolphinCoreOptions.skipIPL
        self.wiiLanguage = NSNumber(value: PVDolphinCoreOptions.wiiLanguage).int8Value
        self.multiPlayer = PVDolphinCoreOptions.multiPlayer
        self.enableLogging = PVDolphinCoreOptions.enableLogging
    }
}
