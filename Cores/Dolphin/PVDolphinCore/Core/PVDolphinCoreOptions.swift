import Foundation
import PVSupport
import PVSettings
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

@objc
// Already over the 600-line limit on develop; it is one declaration per Dolphin
// option. Splitting it belongs in its own change.
// swiftlint:disable:next type_body_length
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

    /// `gsOption` values; mirrored by `PVDolphinCoreBridge.gsPreference` for the running core.
    enum GraphicsBackend: Int {
        case vulkan = 0
        case openGL = 1
        case metal = 2
    }

	static var gsOption: CoreOption = {
		 .enumeration(.init(title: "Graphics Backend",
			   description: "Graphics API to use. Metal recommended on iOS.",
			   requiresRestart: true),
		  values: [
			   .init(title: "Vulkan", description: "Vulkan", value: GraphicsBackend.vulkan.rawValue),
			   .init(title: "OpenGL", description: "OpenGL", value: GraphicsBackend.openGL.rawValue),
			   .init(title: "Metal", description: "Metal (Recommended)", value: GraphicsBackend.metal.rawValue)
		  ],
		  defaultValue: GraphicsBackend.metal.rawValue)
	}()

    static var aspectRatioOption: CoreOption = {
        .enumeration(.init(title: "Aspect Ratio",
                          description: "Aspect ratio for rendering",
                          requiresRestart: false),
                    values: [
                        .init(title: "Auto", description: "Auto", value: 0),
                        // Values are Dolphin's AspectMode: ForceWide (16:9) = 1, ForceStandard (4:3) = 2.
                        .init(title: "Force 4:3", description: "Force 4:3", value: 2),
                        .init(title: "Force 16:9", description: "Force 16:9", value: 1),
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
                          description: "Controls accuracy of the texture cache. Fast provides best performance with minimal visual impact.",
                          requiresRestart: false),
                    values: [
                        .init(title: "Safe", description: "Most accurate, slowest", value: 0),
                        .init(title: "Medium", description: "Balanced accuracy/performance", value: 1),
                        .init(title: "Fast (Recommended)", description: "Best performance, minimal quality loss", value: 2)
                    ],
                    defaultValue: 2)
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
        defaultValue: true)
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
            description: "Use GPU for texture decoding. Provides better performance on modern devices.",
            requiresRestart: false),
        defaultValue: true)
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

    static var viSkipModeOption: CoreOption = {
        .enumeration(.init(title: "VI Skip",
                          description: "Drops video-interface updates to catch up when the CPU lags. Auto is bounded (safe on the jitless core); On can starve vblank IRQs and lock up CPU-heavy titles.",
                          requiresRestart: false),
                    values: [
                        .init(title: "Off", description: "Never skip", value: 0),
                        .init(title: "On", description: "Always skip (legacy, can lock up)", value: 1),
                        .init(title: "Auto (Recommended)", description: "Bounded catch-up", value: 2)
                    ],
                    defaultValue: 2)
    }()

    // MARK: - Shader Settings

    static var shaderCompilationModeOption: CoreOption = {
        .enumeration(.init(title: "Shader Compilation",
                          description: "How shaders are compiled. Hybrid draws a new effect with an ubershader while its specialized shader compiles, so play never stalls.",
                          requiresRestart: false),
                    values: [
                        // Values are Dolphin's ShaderCompilationMode; don't renumber (stored per user).
                        .init(title: "Specialized", description: "Stalls briefly the first time a new effect appears", value: 0),
                        .init(title: "Exclusive Ubershaders", description: "Ubershaders only: no stalls, but slower", value: 1),
                        .init(title: "Hybrid Ubershaders (Recommended)", description: "Ubershaders until the specialized shader is ready: no stalls", value: 2)
                    ],
                    defaultValue: 2)
    }()

    static var waitForShadersOption: CoreOption = {
        .bool(.init(
            title: "Compile Shaders Before Starting",
            description: "Pre-compile shaders at startup to eliminate in-game stuttering. Recommended for best performance.",
            requiresRestart: false),
        defaultValue: true)
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
			   description: "CPU emulation method. JIT provides best performance when available, with automatic fallback.",
			   requiresRestart: true),
		  values: [
			.init(title: "Interpreter", description: "Interpreter (Slowest, Most Compatible)", value: 0),
			.init(title: "Cached Interpreter", description: "Cached Interpreter (Good Performance)", value: 1),
			.init(title: "JIT Recompiler", description: "JIT (Fastest, auto-fallback if unavailable)", value: 2),
			.init(title: "Cached Interpreter (IR)", description: "Experimental IR-lowering engine. Falls back to Cached Interpreter on cores without it.", value: 3)
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
            description: "Run CPU and GPU on separate threads. Faster when stable, but deadlocks most games on the jitless Cached Interpreter — leave OFF unless a specific game needs it.",
            requiresRestart: true),
        defaultValue: false)
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

    static var autoDiscChangeOption: CoreOption = {
        .bool(.init(
            title: "Change Discs Automatically",
            description: "Swaps to the next disc of a multi-disc game when it asks for it.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var accurateNaNsOption: CoreOption = {
        .bool(.init(
            title: "Accurate NaN Emulation",
            description: "Emulates floating-point NaNs exactly. Needed by a few games; slower.",
            requiresRestart: true,
            // Shipped as "Enable Write-Back Cache" while it drove this same setting.
            storageKey: "Enable Write-Back Cache"),
        defaultValue: false)
    }()

    static var accurateCPUCacheOption: CoreOption = {
        .bool(.init(
            title: "Accurate CPU Cache (slower)",
            description: "Emulates the CPU instruction cache accurately. Required by a few games but significantly reduces performance.",
            requiresRestart: true),
        defaultValue: false)
    }()

    static var disableICacheOption: CoreOption = {
        .bool(.init(
            title: "Bypass Instruction Cache",
            description: "Bypass the instruction cache. May improve compatibility in rare cases but can reduce performance.",
            requiresRestart: true),
        defaultValue: false)
    }()

    static var fastFPOption: CoreOption = {
        .bool(.init(
            title: "Fast FP (Cached Interpreter)",
            description: "Use fast floating-point emulation in the Cached Interpreter. Experimental but can significantly improve performance in interpreter mode.",
            requiresRestart: true),
        defaultValue: true)
    }()

    static var dcbzHackOption: CoreOption = {
        .bool(.init(
            title: "DCBZ Hack",
            description: "Skip data cache block zero operations for better performance. Safe for most games.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var relaxedIdleDetectionOption: CoreOption = {
        .bool(.init(
            title: "Relaxed Idle Loop Detection",
            description: "Use relaxed heuristics to detect and skip CPU idle loops. Improves performance especially without JIT.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var fastForwardCTRIdleOption: CoreOption = {
        .bool(.init(
            title: "Fast-Forward CTR Idle Loops",
            description: "Fast-forward through counter-based idle loops. Improves performance especially without JIT.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var dspHLEOption: CoreOption = {
        .bool(.init(
            title: "DSP High Level Emulation (HLE)",
            description: "Use High Level Emulation for the DSP. Faster but less accurate than LLE. Disable for games with DSP audio issues.",
            requiresRestart: true),
        defaultValue: true)
    }()

    static var dspThreadOption: CoreOption = {
        .bool(.init(
            title: "DSP on Separate Thread",
            description: "Run the DSP on a dedicated thread for improved performance. May cause audio desync in some games.",
            requiresRestart: true),
        defaultValue: true)
    }()

    static var syncGPUOption: CoreOption = {
        .bool(.init(
            title: "Synchronize GPU Thread",
            description: "Sync the GPU thread to the CPU, ensuring accurate timing. Reduces performance but fixes flickering in some games. Only relevant in Dual Core mode.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var fastDiscSpeedOption: CoreOption = {
        .bool(.init(
            title: "Fast Disc Speed",
            description: "Skip disc read speed emulation for faster loading times. May break games that depend on precise disc timing.",
            requiresRestart: false),
        defaultValue: true)
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
                          description: "Audio output method. Core Audio keeps Provenance's audio session settings; AVAudioEngine switches the session to Playback.",
                          requiresRestart: true),
                    values: [
                        // Value 0 was Cubeb; it now maps to Core Audio so stored choices move off Cubeb.
                        .init(title: "Core Audio (Recommended)", description: "Core Audio", value: 0),
                        .init(title: "OpenAL", description: "OpenAL", value: 1),
                        .init(title: "Null", description: "No Audio", value: 2),
                        .init(title: "AVAudioEngine", description: "AVAudioEngine (spatial audio on headphones)", value: 3)
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

    static var enableHapticFeedbackOption: CoreOption = {
        .bool(.init(
            title: "Enable Haptic Feedback",
            description: "Enable haptic feedback (rumble) using device vibration. Requires compatible iOS device.",
            requiresRestart: false),
        defaultValue: true)
    }()

    static var enableGyroMotionControlsOption: CoreOption = {
        .bool(.init(
            title: "Enable Gyro Motion Controls",
            description: "Use iPhone/iPad gyroscope for Wiimote gyro controls. Tilt left/right and forward/back for motion sensing.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var enableGyroIRCursorOption: CoreOption = {
        .bool(.init(
            title: "Enable Gyro IR Cursor",
            description: "Use iPhone/iPad gyroscope to control Wiimote IR cursor. Alternative to touch screen control.",
            requiresRestart: false),
        defaultValue: false)
    }()

    static var disableJoystickIRCursorOption: CoreOption = {
        .bool(.init(
            title: "Disable Joystick IR Control",
            description: "Disable joystick control of IR cursor to prevent conflicts with touch/gyro input.",
            requiresRestart: false),
        defaultValue: false)
    }()

    // MARK: - Cached Interpreter (CIR) flags

    /// One iCube Cached Interpreter flag: its `[Core]` ini key and the core's compiled default.
    struct CIRFlag {
        let key: String
        let title: String
        let description: String
        let defaultValue: Bool
    }

    /// Every user-facing CIR flag in iCube's MainSettings.cpp, with iCube's compiled defaults: the
    /// measured wins are on, the experiments off. Not listed: the *Validate twins (debug), CIRProfile,
    /// the tape prefetch ints, CIRTailLink (unread by the core) and the CIRIR* flags (IR engine only).
    /// Titles are the option storage keys: the five experiments that shipped before keep their titles.
    static let cirFlags: [CIRFlag] = [
        // On by default (measured wins)
        .init(key: "CIRBlockLinking", title: "CIR: Block Linking",
              description: "Jumps straight from one cached block to the next instead of returning to the dispatcher. The biggest Cached Interpreter win.",
              defaultValue: true),
        .init(key: "CIRDynLinking", title: "CIR: Dynamic Block Linking",
              description: "Remembers the last indirect-branch target of each block and jumps straight to it. Needs Block Linking.",
              defaultValue: true),
        .init(key: "CIRSpecializedOps", title: "CIR: Specialized Integer Ops",
              description: "Calls integer instruction handlers directly instead of through the generic dispatch.",
              defaultValue: true),
        .init(key: "CIRPICLoadStore", title: "CIR: Fast Integer Load/Store",
              description: "Fast path for integer loads and stores to normal RAM.",
              defaultValue: true),
        .init(key: "CIRMicroOpFusion", title: "CIR: Micro-op Fusion",
              description: "Fuses runs of simple integer instructions into one step.",
              defaultValue: true),
        .init(key: "CIRMemMicroOps", title: "CIR: Fused Load/Store Micro-ops",
              description: "Packs integer loads and stores into fused micro-op runs. Needs Fast Integer Load/Store and Micro-op Fusion.",
              defaultValue: true),
        .init(key: "CIRMicroPairs", title: "CIR: Micro-op Pairs",
              description: "Runs two adjacent micro-ops in one dispatch.",
              defaultValue: true),
        .init(key: "CIRRecordChaining", title: "CIR: Record Chaining",
              description: "Chains consecutive steps together instead of returning to the executor loop between each.",
              defaultValue: true),
        .init(key: "CIRLongBlocks", title: "CIR: Long Blocks",
              description: "Lets a block run on past not-taken branches and through calls, so there are fewer block transitions.",
              defaultValue: true),
        // Off by default (experiments)
        .init(key: "CIRSpecializedFpLs", title: "CIR: FP Load/Store Specialization",
              description: "Direct-dispatch floating-point loads and stores. Measured as noise.",
              defaultValue: false),
        .init(key: "CIRSpecializedPsq", title: "CIR: Paired-Single Load/Store Specialization",
              description: "Direct-dispatch quantized paired-single loads and stores. Experimental.",
              defaultValue: false),
        .init(key: "CIRPsqFastPath", title: "CIR: Paired-Single Fast Path",
              description: "Float fast path inside the paired-single quantize handlers. Measured as noise.",
              defaultValue: false),
        .init(key: "CIRPsNeon", title: "CIR: NEON Paired-Single Math",
              description: "SIMD paired-single arithmetic on ARM64. Measured as noise.",
              defaultValue: false),
        .init(key: "CIRCacheLoopFF", title: "CIR: Cache-Loop Fast-Forward",
              description: "Fast-forwards dcbf/dcbi/dcbst cache loops. Measured as noise.",
              defaultValue: false),
        .init(key: "CIRSpecializedFpArith", title: "CIR: FP Arithmetic Specialization",
              description: "Direct-dispatch floating-point arithmetic. Experimental.",
              defaultValue: false),
        .init(key: "CIRDeadFlagElim", title: "CIR: Dead Flag Elimination",
              description: "Skips computing CR0 when nothing reads it. Experimental.",
              defaultValue: false),
        .init(key: "CIRDeadFprfElim", title: "CIR: Dead FPRF Elimination",
              description: "Skips computing FP result flags when nothing reads them. Experimental; FP-sensitive games may break.",
              defaultValue: false),
        .init(key: "CIRStoreLoopFF", title: "CIR: Store-Loop Fast-Forward",
              description: "Fast-forwards simple memory-fill store loops. Experimental.",
              defaultValue: false),
        .init(key: "CIRDynTargetCache", title: "CIR: Dynamic Target Cache",
              description: "Caches indirect-branch targets by address so returns hit from any caller. Experimental; measured within noise.",
              defaultValue: false),
        .init(key: "CIRGatherPipeCopyFusion", title: "CIR: Gather-Pipe Copy Fusion",
              description: "Fuses copy loops into the GPU gather pipe. Experimental.",
              defaultValue: false),
        .init(key: "CIRSkipPerfMonitor", title: "CIR: Skip Performance Monitor",
              description: "Stops emulating the CPU performance counters (about 4 % faster). Breaks games that read them.",
              defaultValue: false),
        .init(key: "CachedInterpreterPrefetch", title: "CIR: Software Prefetch",
              description: "Adds manual prefetch hints. Usually slower on Apple chips, whose hardware prefetcher does better.",
              defaultValue: false)
    ]

    static let cirFlagOptions: [CoreOption] = cirFlags.map { flag in
        .bool(.init(title: flag.title, description: flag.description, requiresRestart: true),
              defaultValue: flag.defaultValue)
    }

    // MARK: - Diagnostics

    static var stallMetricsOption: CoreOption = {
        .bool(.init(
            title: "Stall Metrics",
            description: "Per-site stall/wasted-time instrumentation (where the CPU thread waits). Low overhead; feeds the perf report.",
            requiresRestart: true),
        defaultValue: true)
    }()

    static var cirCacheLoopFFValidateOption: CoreOption = {
        .bool(.init(
            title: "CIR: Cache-Loop Validate (slow)",
            description: "Double-run correctness check for Cache-Loop Fast-Forward. Debug only — very slow.",
            requiresRestart: true),
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
            vbiFrequencyRangeOption, enableMMUOption, autoDiscChangeOption,
            accurateCPUCacheOption, disableICacheOption, fastFPOption,
            dcbzHackOption, relaxedIdleDetectionOption, fastForwardCTRIdleOption,
            accurateNaNsOption, speedLimitOption, fallbackRegionOption,
            dspHLEOption, dspThreadOption, syncGPUOption, fastDiscSpeedOption
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
            viSkipModeOption
        ]
        let hacksGroup: CoreOption = .group(.init(title: "Graphics Hacks",
                                                description: "Advanced graphics hacks for performance and compatibility. Change with caution."),
                                          subOptions: hacksOptions)

        // System Settings Group
        let systemOptions: [CoreOption] = [
            skipIPLOption, wiiLanguageOption, multiPlayerOption, enableLoggingOption, enableHapticFeedbackOption, enableGyroMotionControlsOption, enableGyroIRCursorOption, disableJoystickIRCursorOption
        ]
        let systemGroup: CoreOption = .group(.init(title: "System",
                                                  description: "GameCube and Wii system settings"),
                                            subOptions: systemOptions)

        // Cached Interpreter groups: the measured wins (on by default) and the experiments (off)
        let cirOptimizationOptions = zip(cirFlags, cirFlagOptions).filter { $0.0.defaultValue }.map(\.1)
        let cirOptimizationGroup: CoreOption = .group(.init(title: "Cached Interpreter Optimizations",
                                                           description: "Measured speedups for the Cached Interpreter, on by default. Turn one off only to A/B test or rule it out."),
                                                     subOptions: cirOptimizationOptions)
        let cirExperimentOptions = zip(cirFlags, cirFlagOptions).filter { !$0.0.defaultValue }.map(\.1)
        let cirGroup: CoreOption = .group(.init(title: "Advanced CPU (CIR)",
                                               description: "Experimental Cached Interpreter optimizations, off by default. For testing; some can break games."),
                                         subOptions: cirExperimentOptions)

        // Diagnostics Group
        let diagnosticsOptions: [CoreOption] = [
            stallMetricsOption, cirCacheLoopFFValidateOption
        ]
        let diagnosticsGroup: CoreOption = .group(.init(title: "Diagnostics",
                                                       description: "Performance instrumentation and validation tools"),
                                                 subOptions: diagnosticsOptions)

		options.append(contentsOf: [graphicsGroup, enhancementGroup, hacksGroup, aaGroup, shaderGroup, cpuGroup, cirOptimizationGroup, cirGroup, audioGroup, systemGroup, diagnosticsGroup])
		return options
	}
}

@objc public extension PVDolphinCoreOptions {
    // MARK: - Graphics Settings

	@objc static var resolution: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.resolutionOption).asInt ?? 1
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
    @objc static var viSkipMode: Int {
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.viSkipModeOption).asInt ?? 2
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
    @objc static var autoDiscChange: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.autoDiscChangeOption).asBool
    }
    @objc static var accurateNaNs: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.accurateNaNsOption).asBool
    }
    @objc static var accurateCPUCache: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.accurateCPUCacheOption).asBool
    }
    @objc static var disableICache: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.disableICacheOption).asBool
    }
    @objc static var fastFP: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastFPOption).asBool
    }
    @objc static var dcbzHack: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.dcbzHackOption).asBool
    }
    @objc static var relaxedIdleDetection: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.relaxedIdleDetectionOption).asBool
    }
    @objc static var fastForwardCTRIdle: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastForwardCTRIdleOption).asBool
    }
    /// `[Core]` ini key → value for every CIR flag, for PVDolphinCore's setOptionValues.
    @objc static var cirFlagValues: [String: NSNumber] {
        Dictionary(uniqueKeysWithValues: zip(cirFlags, cirFlagOptions).map { flag, option in
            (flag.key, NSNumber(value: PVDolphinCore.valueForOption(option).asBool))
        })
    }
    @objc static var stallMetrics: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.stallMetricsOption).asBool
    }
    @objc static var cirCacheLoopFFValidate: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.cirCacheLoopFFValidateOption).asBool
    }
    @objc static var dspHLE: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.dspHLEOption).asBool
    }
    @objc static var dspThread: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.dspThreadOption).asBool
    }
    @objc static var syncGPU: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.syncGPUOption).asBool
    }
    @objc static var fastDiscSpeed: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastDiscSpeedOption).asBool
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
    /// Resolved Wii language: per-core option takes priority, then global PVSettings,
    /// then system locale.
    @objc static var wiiLanguage: Int {
        let perCoreValue = PVDolphinCore.valueForOption(PVDolphinCoreOptions.wiiLanguageOption).asInt ?? 1
        let globalRaw = PVSettingsWrapper.coreLanguageRawValue
        if globalRaw >= 0 {
            let globalWii = CoreLocaleMapper.wiiLanguageID(fromRetroArch: globalRaw)
            if perCoreValue == 1, globalWii != 1 {
                return globalWii
            }
        } else if perCoreValue == 1 {
            return CoreLocaleMapper.currentWiiLanguageID
        }
        return perCoreValue
    }
    @objc static var multiPlayer: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.multiPlayerOption).asBool
    }
    @objc static var enableLogging: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableLoggingOption).asBool
    }
    @objc static var enableHapticFeedback: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableHapticFeedbackOption).asBool
    }
    @objc static var enableGyroMotionControls: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableGyroMotionControlsOption).asBool
    }
    @objc static var enableGyroIRCursor: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableGyroIRCursorOption).asBool
    }
    @objc static var disableJoystickIRCursor: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.disableJoystickIRCursorOption).asBool
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

        // Graphics Hacks — these were NEVER plumbed before (UI-only options): the bridge
        // properties stayed at ObjC default false/0, so the .mm wrote the SLOW path into
        // Dolphin Config regardless of settings (EFB copies to RAM, no immediate XFB, no GPU
        // texture decoding, Safe texture cache). Wiring them is itself a perf fix.
        self.skipEFBAccessFromCPU = PVDolphinCoreOptions.skipEFBAccessFromCPU
        self.ignoreFormatChanges = PVDolphinCoreOptions.ignoreFormatChanges
        self.storeEFBCopiesToTextureOnly = PVDolphinCoreOptions.storeEFBCopiesToTextureOnly
        self.deferEFBCopies = PVDolphinCoreOptions.deferEFBCopies
        self.textureCacheAccuracy = NSNumber(value: PVDolphinCoreOptions.textureCacheAccuracy).int8Value
        self.storeXFBCopiesToTextureOnly = PVDolphinCoreOptions.storeXFBCopiesToTextureOnly
        self.immediateXFB = PVDolphinCoreOptions.immediateXFB
        self.skipDuplicateXFBs = PVDolphinCoreOptions.skipDuplicateXFBs
        self.gpuTextureDecoding = PVDolphinCoreOptions.gpuTextureDecoding
        self.fastDepthCalculation = PVDolphinCoreOptions.fastDepthCalculation
        self.disableBoundingBox = PVDolphinCoreOptions.disableBoundingBox
        self.saveTextureCacheToState = PVDolphinCoreOptions.saveTextureCacheToState
        self.vertexRounding = PVDolphinCoreOptions.vertexRounding
        self.viSkipMode = NSNumber(value: PVDolphinCoreOptions.viSkipMode).int8Value

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
        self.autoDiscChange = PVDolphinCoreOptions.autoDiscChange
        self.accurateNaNs = PVDolphinCoreOptions.accurateNaNs
        self.accurateCPUCache = PVDolphinCoreOptions.accurateCPUCache
        self.disableICache = PVDolphinCoreOptions.disableICache
        self.fastFP = PVDolphinCoreOptions.fastFP
        self.dcbzHack = PVDolphinCoreOptions.dcbzHack
        self.relaxedIdleDetection = PVDolphinCoreOptions.relaxedIdleDetection
        self.fastForwardCTRIdle = PVDolphinCoreOptions.fastForwardCTRIdle
        self.cirFlags = PVDolphinCoreOptions.cirFlagValues
        self.stallMetrics = PVDolphinCoreOptions.stallMetrics
        self.cirCacheLoopFFValidate = PVDolphinCoreOptions.cirCacheLoopFFValidate
        self.dspHLE = PVDolphinCoreOptions.dspHLE
        self.dspThread = PVDolphinCoreOptions.dspThread
        self.syncGPU = PVDolphinCoreOptions.syncGPU
        self.fastDiscSpeed = PVDolphinCoreOptions.fastDiscSpeed
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
        self.enableHapticFeedback = PVDolphinCoreOptions.enableHapticFeedback
        self.enableGyroMotionControls = PVDolphinCoreOptions.enableGyroMotionControls
        self.enableGyroIRCursor = PVDolphinCoreOptions.enableGyroIRCursor
        self.disableJoystickIRCursor = PVDolphinCoreOptions.disableJoystickIRCursor
    }
}

extension PVDolphinCoreBridge: EmulatorCoreScalingModeApplying {
    /// Re-applies the aspect setting for the app's scaling mode and relays the render view out.
    public func applyUserScalingMode() {
        applyAspectRatioSetting()
    }

    /// Height in pixels of the picture Integer Scale and Native Resolution measure against:
    /// the 640x480 output a GameCube or Wii game's video interface produces.
    static let nativeOutputPixelHeight: CGFloat = 480

    /// Where the render layer goes inside a render view of `container` points, for the user's
    /// scaling mode (shared `ScalingModeLayout` maths). The whole container unless
    /// `sizesRenderLayerForScalingMode`, when Dolphin itself fits or stretches to it. Aspect
    /// Fill's rect is larger than the container, which the render view clips.
    func renderLayerFrame(inContainer container: CGSize, scale: CGFloat) -> CGRect {
        let whole = CGRect(origin: .zero, size: container)
        guard sizesRenderLayerForScalingMode else { return whole }

        var aspect = gameDisplayAspect
        if aspect <= 0, videoHeight > 0 {
            // Dolphin hasn't reported what it draws yet (before the first frames).
            aspect = CGFloat(videoWidth) / CGFloat(videoHeight)
        }
        return ScalingModeLayout.frame(for: Defaults[.scalingMode],
                                       container: container,
                                       contentAspect: aspect,
                                       nativePixelHeight: Self.nativeOutputPixelHeight,
                                       screenScale: scale)
    }
}
