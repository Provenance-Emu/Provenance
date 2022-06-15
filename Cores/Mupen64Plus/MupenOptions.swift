	//
	//  MupenOptions.swift
	//  PVMupen64Plus
	//
	//  Created by Joseph Mattiello on 4/11/18.
	//  Copyright © 2018 Provenance. All rights reserved.
	//

import Foundation
import PVSupport

extension MupenGameCore: CoreOptional {
		//    public func valueForOption<T>(_ option: CoreOption<T>) -> T where T : Decodable, T : Encodable {
		//
		//    }
    
    // MARK: Dual-Joystick
    // Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more
    static var dualJoystickOption: CoreOption = {
        .bool(.init(
            title: "Dual joystick on first player",
            description: "If 1st player controller has dual joysticks, use the right joystick as player 2. For games, such as GoldenEye, that support using 2 N64 controllers for single player input.",
            requiresRestart: false))
    }()
    
    static func controllerPakOption(forController index: Int) -> CoreOption {
        /*
         #define PLUGIN_NONE                 1
         #define PLUGIN_MEMPAK               2
         #define PLUGIN_RUMBLE_PAK           3 /* not implemented for non raw data */
         #define PLUGIN_TRANSFER_PAK         4 /* not implemented for non raw data */
         #define PLUGIN_RAW                  5 /* the controller plugin is passed in raw data */
         */
        let defaultValue = index <= 1 ? 2 : 5
        return .enumeration(.init(title: "Controller Pak \(index)",
                                                description: nil,
                                                requiresRestart: true),
                                          values:[
                                            .init(title: "None", description: "", value: 1),
                                            .init(title: "Memory Pak", description: "", value: 2),
//                                            .init(title: "Rumble Pak, description: "", value: 3),
//                                            .init(title: "Transer Pak", description: "", value: 4),
                                            .init(title: "Raw Data", description: "Used for Rumble or Transer Pak", value: 5),
                                          ],
                     defaultValue: defaultValue)
    }
    
    static var controllerPak1: CoreOption = controllerPakOption(forController: 1)
    static var controllerPak2: CoreOption = controllerPakOption(forController: 2)
    static var controllerPak3: CoreOption = controllerPakOption(forController: 3)
    static var controllerPak4: CoreOption = controllerPakOption(forController: 4)

	public static var options: [CoreOption] {
		var options = [CoreOption]()

			// MARK: -- Plugins

		let videoPluginOption = CoreOption.multi(.init(title: "GFX Plugin",
													   description: "GlideN64 is newer but slower. Try Rice for older devices."), values: [
														.init(title: "GlideN64", description: "Newer, GLES3 GFX Driver"),
														.init(title: "Rice Video", description: "Older, faster, less feature rich GFX Driver.")])

		let rspOptions = CoreOption.multi(.init(title: "RSP Plugin", description: nil), values: [
			.init(title: "RSPHLE", description: "Faster, default RSP"),
			.init(title: "CXD4", description: "Slower. More features for some games, breaks others.")])

		let pluginsGroup = CoreOption.group(.init(title: "Plugins", description: nil),
											subOptions: [videoPluginOption, rspOptions])
        
        // MARK: -- Controls
        let controlOptions: [CoreOption] = [dualJoystickOption, controllerPak1, controllerPak2, controllerPak3, controllerPak4]
        let controlGroup:CoreOption = .group(.init(title: "Controls", description: ""),
                                             subOptions: controlOptions)

			// MARK: -- Core
		var coreOptions = [CoreOption]()

			// MARK: R4300Emulator <Enum=1>
			// Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more
		coreOptions.append(.enumeration(.init(title: "CPU Mode",
											  description: nil,
											  requiresRestart: true),
										values:[
											.init(title: "Pure Interpreter", description: "Slowest", value: 0),
											.init(title: "Cached Interpreter", description: "Default", value: 1),
											.init(title: "Dynamic Recompiler", description: "Fastest but requires JIT or will crash", value: 2)],
                                        defaultValue: 1))

		coreOptions.append(.range(.init(title: "Count Per Operation",
										description: "Force number of cycles per emulated instruction.",
										requiresRestart: true),
								  range: .init(defaultValue: 2, min: 1, max: 4), defaultValue: 2))

		coreOptions.append(.bool(.init(title: "Disable Extra Memory",
									   description: "Disable 4MB expansion RAM pack. May be necessary for some games.",
									   requiresRestart: true),
								 defaultValue: false))

		coreOptions.append(.range(.init(title: "SiDmaDuration",
										description: "Duration of SI DMA (-1: use per game settings)",
										requiresRestart: true),
								  range: .init(defaultValue: -1, min: -1, max: 255), defaultValue: -1))

		coreOptions.append(.bool(.init(title: "Randomize Interrupt",
									   description: "Randomize PI/SI Interrupt Timing.",
									   requiresRestart: true),
								 defaultValue: true))

			// MARK: --- DEBUG
			// MARK: OSD <Bool=0>
			// Draw on-screen display if True, otherwise don't draw OSD
		coreOptions.append(.bool(.init(title: "Debug OSD",
									   description: "Draw on-screen display if True, otherwise don't draw OSD",
									   requiresRestart: true),
								 defaultValue: false))


		let coreGroup:CoreOption = .group(.init(title: "Mupen Core", description: "Global options for Mupen"),
										  subOptions: coreOptions)

			// MARK: -- GLideN64
		var glidenOptions = [CoreOption]()

#warning("Maybe make an enum type for core options?")
			// MARK: AspectRatio <Enum>
			// 0 = stretch, 1 = 4:3, 2 = 16:9, 3 = adjust
		glidenOptions.append(.enumeration(.init(title: "Aspect Ratio",
												description: nil,
												requiresRestart: true),
										  values:[
											.init(title: "Stretch", description: "Slowest", value: 0),
											.init(title: "4:3", description: "Default", value: 1),
											.init(title: "16:9", description: "Fastest but bequires JIT or will crash", value: 2),
											.init(title: "Adjust", description: "Default", value: 3)],
                                          defaultValue: 3))


			// MARK: EnableHWLighting <Bool=0>
		glidenOptions.append(.bool(.init(title: "Hardware Lighting", description: "Per-pixel lighting", requiresRestart: true), defaultValue: true))
			// MARK: fullscreenRefresh <Int=60>

			// MARK: MultiSampling <Enum=0>
			// "Enable/Disable MultiSampling (0=off, 2,4,8,16=quality
			// WARNING: anything other than 0 crashes shader compilation
		glidenOptions.append(.enumeration(.init(title: "Multi Sampling",
												description: "Anything other than Off will probably crash. You've been warned.",
												requiresRestart: true),
										  values:[
											.init(title: "Off", description: "", value: 0),
											.init(title: "2x", description: "", value: 2),
											.init(title: "4x", description: "", value: 4),
											.init(title: "8x", description: "", value: 8),
											.init(title: "16x", description: "", value: 16)]))

			// MARK: ForceGammaCorrection <Bool=0>
		glidenOptions.append(.bool(.init(title: "Force Gamma Correction", description: nil, requiresRestart: true), defaultValue: false))

			// MARK: gammaCorrection <Float>
		glidenOptions.append(.rangef(.init(title: "Gamma Correction", description: "Stength of gamma correction", requiresRestart: true), range: CoreOptionRange<Float>(defaultValue: 0.5, min: 0, max: 1), defaultValue: 0.5))

			// MARK: --- Textures

			// MARK: txSaveCache <Bool=1>
		glidenOptions.append(.bool(.init(title: "Save texture cache", description: "Save textures to cache for faster loading later", requiresRestart: true), defaultValue: true))

			// MARK: txCacheCompression <Bool=0>
		glidenOptions.append(.bool(.init(title: "Compress texture cache", description: "Compress Texture Cache", requiresRestart: true), defaultValue: true))

			// MARK: txEnhancementMode <Enum=11>
			// 0=none, 1=store as is, 2=X2, 3=X2SAI, 4=HQ2X, 5=HQ2XS, 6=LQ2X, 7=LQ2XS, 8=HQ4X, 9=2xBRZ, 10=3xBRZ, 11=4xBRZ, 12=5xBRZ), 13=6xBRZ
		glidenOptions.append(.enumeration(.init(title: "Texture Enhancement Mode",
												description: nil,
												requiresRestart: true),
										  values:[
											.init(title: "None", description: "", value: 0),
											.init(title: "Store as-is", description: "", value: 1),
											.init(title: "X2", description: "", value: 2),
											.init(title: "X2SAI", description: "", value: 3),
											.init(title: "HQ2X", description: "", value: 4),
											.init(title: "HQ2XS", description: "", value: 5),
											.init(title: "LQ2X", description: "", value: 6),
											.init(title: "LQXS", description: "", value: 7),
											.init(title: "HQ4X", description: "", value: 8),
											.init(title: "2xBRZ", description: "", value: 9),
											.init(title: "3xBZ", description: "", value: 10),
											.init(title: "4xBRZ", description: "", value: 11),
											.init(title: "5xBRZ", description: "", value: 12),
											.init(title: "6xBRZ", description: "", value: 13),
										  ],
                                         defaultValue: 0))

			// MARK: txFilterMode <Enum=0>
			// Texture filter (0=none, 1=Smooth filtering 1, 2=Smooth filtering 2, 3=Smooth filtering 3, 4=Smooth filtering 4, 5=Sharp filtering 1, 6=Sharp filtering 2)
		glidenOptions.append(.enumeration(.init(title: "Texture Filter Mode",
												description: nil,
												requiresRestart: true),
										  values:[
											.init(title: "None", description: "", value: 0),
											.init(title: "Smooth 1", description: "", value: 1),
											.init(title: "Smooth 2", description: "", value: 2),
											.init(title: "Smooth 3", description: "", value: 3),
											.init(title: "Smooth 4", description: "", value: 4),
											.init(title: "Sharp 1", description: "", value: 5),
											.init(title: "Sharp 2", description: "", value: 6),
										  ]))



			// MARK: txFilterIgnoreBG <Bool=0>
			// "Don't filter background textures."
		glidenOptions.append(.bool(.init(title: "Ignore BG Textures", description: "Don't filter background textures.", requiresRestart: true), defaultValue: false))

			// MARK: txCacheSize <Int=104857600>
			// MARK: txDump <Bool=0>
			//	"Enable dump of loaded N64 textures.
		glidenOptions.append(.bool(.init(title: "Texture Dump", description: "Enable dump of loaded N64 textures.", requiresRestart: true), defaultValue: false))

			// MARK: txForce16bpp <Bool=0>
			// "Force use 16bit texture formats for HD textures."
		glidenOptions.append(.bool(.init(title: "Force 16bpp textures", description: "Force use 16bit texture formats for HD textures.", requiresRestart: true), defaultValue: false))

			// MARK: ---- HiRes
			// MARK: txHiresEnable <Bool=0>
		glidenOptions.append(.bool(.init(title: "Enable HiRes Texture packs", description: "These must be installed seperately. Refer to our WIKI for HD textures.", requiresRestart: true), defaultValue: true))

			// MARK: txHresAltCRC <Bool=0>
			// "Use alternative method of paletted textures CRC calculation."
		glidenOptions.append(.bool(.init(title: "HiRes Alt CRC", description: "Use alternative method of paletted textures CRC calculation.", requiresRestart: true), defaultValue: false))

			// MARK: txHiresFullAlphaChannel <Bool=0>
			// "Allow to use alpha channel of high-res texture fully."
		glidenOptions.append(.bool(.init(title: "HiRes Full Alpha", description: "Allow to use alpha channel of high-res texture fully.", requiresRestart: true), defaultValue: true))

			// MARK: --- Bloom
		glidenOptions.append(.bool(.init(title: "Bloom filter", description: nil, requiresRestart: true), defaultValue: false))
			// TODO: Add another sub-group, auto disable if off (maybe more work than worth)

			//		[bloomFilter]
			//		enable=0
			//		thresholdLevel=4
			//		blendMode=0
			//		blurAmount=10
			//		blurStrength=20

		let glidenGroup:CoreOption = .group(.init(title: "GLideN64", description: "Options specific to the GLideN64 video plugin"),
											subOptions: glidenOptions)

			// MARK: -- RICE
		var riceOptions = [CoreOption]()

		riceOptions.append(.bool(.init(title: "Fast Texture Loading", description: "Use a faster algorithm to speed up texture loading and CRC computation", requiresRestart: true), defaultValue: false))

		riceOptions.append(.bool(.init(title: "DoubleSizeForSmallTxtrBuf", description: "Enable this option to have better render-to-texture quality", requiresRestart: true), defaultValue: true))

		riceOptions.append(.bool(.init(title: "FullTMEMEmulation", description: "N64 Texture Memory Full Emulation (may fix some games, may break others)", requiresRestart: true), defaultValue: false))

		riceOptions.append(.bool(.init(title: "SkipFrame", description: "If this option is enabled, the plugin will skip every other frame. Breaks some games in my testing ", requiresRestart: true), defaultValue: false))

		riceOptions.append(.bool(.init(title: "LoadHiResTextures", description: "Enable hi-resolution texture file loading", requiresRestart: true), defaultValue: true))

		/*

		 // Use fullscreen mode if True, or windowed mode if False
		 int fullscreen = 1;
		 ConfigSetParameter(rice, "Fullscreen", M64TYPE_BOOL, &fullscreen);

		 // Use Mipmapping? 0=no, 1=nearest, 2=bilinear, 3=trilinear
		 int mipmapping = 0;
		 ConfigSetParameter(rice, "Mipmapping", M64TYPE_INT, &mipmapping);

		 // Enable/Disable Anisotropic Filtering for Mipmapping (0=no filtering, 2-16=quality).
		 // This is uneffective if Mipmapping is 0. If the given value is to high to be supported by your graphic card, the value will be the highest value your graphic card can support. Better result with Trilinear filtering
		 int anisotropicFiltering = 16;
		 ConfigSetParameter(rice, "AnisotropicFiltering", M64TYPE_INT, &anisotropicFiltering);

		 // Enable, Disable or Force fog generation (0=Disable, 1=Enable n64 choose, 2=Force Fog)
		 int fogMethod = 0;
		 ConfigSetParameter(rice, "FogMethod", M64TYPE_INT, &fogMethod);

		 // Color bit depth to use for textures (0=default, 1=32 bits, 2=16 bits)
		 // 16 bit breaks some games like GoldenEye
		 int textureQuality = 0;
		 ConfigSetParameter(rice, "TextureQuality", M64TYPE_INT, &textureQuality);

		 // Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)
		 int multiSampling = RESIZE_TO_FULLSCREEN ? 4 : 0;
		 ConfigSetParameter(rice, "MultiSampling", M64TYPE_INT, &multiSampling);

		 // Color bit depth for rendering window (0=32 bits, 1=16 bits)
		 int colorQuality = 0;
		 ConfigSetParameter(rice, "ColorQuality", M64TYPE_INT, &colorQuality);
		 */
			// MARK: ColorQuality <Enum=>
			// 0 = 32 bits, 1 = 16 bits
		riceOptions.append(.multi(.init(title: "Color Quality",
										description: "Color bit depth for rendering window",
										requiresRestart: true),
								  values:[
									.init(title: "32 Bits", description: ""),
									.init(title: "16 Bits", description: "")]))

		let riceGroup:CoreOption = .group(.init(title: "RICE", description: "Options specific to the RICE video plugin"),
										  subOptions: riceOptions)



			// MARK: -- Video (Globa)
			//        let videoGroup = CoreOption.group(.init(title: "Video"),
			//										  subOptions: [glidenGroup, riceGroup])
		
		options.append(contentsOf: [coreGroup, pluginsGroup, controlGroup, /*videoGroup,*/ glidenGroup, riceGroup])
		return options
	}
}

@objc
extension MupenGameCore {
		// TODO: move these generall accessors somewhere global, maybe use dynamicC
	@objc
	static public func bool(forOption option: String) -> Bool {
		return storedValueForOption(Bool.self, option) ?? false
	}

	@objc
	static public func int(forOption option: String) -> Int {
		let value = storedValueForOption(Int.self, option)
		return value ?? 0
	}

	@objc
	static public func float(forOption option: String) -> Float {
		let value = storedValueForOption(Float.self, option)
		return value ?? 0
	}

	@objc
	static public func string(forOption option: String) -> String? {
		let value = storedValueForOption(String.self, option)
		return value
	}

	public static var useRice: Bool {
		return storedValueForOption(String.self, "GFX Plugin") == "Rice Video"
	}

	public static var useCXD4: Bool {
		return storedValueForOption(String.self, "RSP Plugin") == "CXD4"
	}

	public static var perPixelLighting: Bool {
		return storedValueForOption(Bool.self, "Hardware Lighting") ?? false
	}
}

@objc public extension MupenGameCore {
  @objc var dualJoystickOption: Bool { MupenGameCore.valueForOption(MupenGameCore.dualJoystickOption).asBool }
    
    @objc var controllerPak1Option: Int { MupenGameCore.valueForOption(MupenGameCore.controllerPak1).asInt ?? 1 }
    @objc var controllerPak2Option: Int { MupenGameCore.valueForOption(MupenGameCore.controllerPak2).asInt ?? 1 }
    @objc var controllerPak3Option: Int { MupenGameCore.valueForOption(MupenGameCore.controllerPak3).asInt ?? 1 }
    @objc var controllerPak4Option: Int { MupenGameCore.valueForOption(MupenGameCore.controllerPak4).asInt ?? 1 }

    func parseOptions() {
        self.dualJoystick = dualJoystickOption
        self.setMode(controllerPak1Option, forController: 0)
        self.setMode(controllerPak2Option, forController: 1)
        self.setMode(controllerPak3Option, forController: 2)
        self.setMode(controllerPak4Option, forController: 3)
    }
}
