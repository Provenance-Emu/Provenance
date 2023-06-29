import Foundation

extension PVPPSSPPCore: CoreOptional {
	 static var resolutionOption: CoreOption = {
		  .enumeration(.init(title: "Resolution Upscaling",
				description: "(Requires Restart)",
				requiresRestart: true),
			values: [
				.init(title: "1X", description: "1X", value: 1),
				.init(title: "2X", description: "2X", value: 2),
				.init(title: "3X", description: "3X", value: 3),
				.init(title: "4X", description: "4X", value: 4),
				.init(title: "5X", description: "5X", value: 5),
				.init(title: "6X", description: "6X", value: 6),
				.init(title: "7X", description: "7X", value: 7),
				.init(title: "8X", description: "8X", value: 8),
				.init(title: "16X", description: "16X", value: 16),
			],
			defaultValue: 2)
			}()

	static var gsOption: CoreOption = {
		 .enumeration(.init(title: "Graphics Handler",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		  values: [
			   .init(title: "Vulkan", description: "Vulkan", value: 3),
			   .init(title: "OpenGL", description: "OpenGL", value: 0)
		  ],
		  defaultValue: 0)
	}()

	static var textureAnisotropicOption: CoreOption = {
		 .enumeration(.init(title: "Texture Anisotropic Filtering",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "Disabled", description: "Disabled", value: 0),
			   .init(title: "2x", description: "2X", value: 1),
			   .init(title: "4X", description: "4X", value: 2),
			   .init(title: "8X", description: "8X", value: 3),
			   .init(title: "16X", description: "16X", value: 4)
		   ],
		   defaultValue: 4)
		   }()

	static var textureFilterOption: CoreOption = {
		 .enumeration(.init(title: "Texture Filtering",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "Auto", description: "Auto", value: 1),
			   .init(title: "Nearest", description: "Nearest", value: 2),
			   .init(title: "Linear", description: "Linear", value: 3),
			   .init(title: "Auto max quality", description: "Auto max quality", value: 4)
		   ],
		   defaultValue: 1)
		   }()

	static var textureUpscaleTypeOption: CoreOption = {
		 .enumeration(.init(title: "Texture Upscaling Type",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "xBRZ", description: "xBRZ", value: 0),
			   .init(title: "Hybrid", description: "Hybrid", value: 1),
			   .init(title: "Bicubic", description: "Bicubic", value: 2),
			   .init(title: "Hybrid + Bicubic", description: "Hybrid + Bicubic", value: 3)
		   ],
		   defaultValue: 0)
		   }()
	static var textureUpscaleOption: CoreOption = {
		 .enumeration(.init(title: "Texture Upscaling Level",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "Disabled", description: "Disabled", value: 1),
			   .init(title: "2x", description: "2X", value: 2),
			   .init(title: "3X", description: "3X", value: 3),
			   .init(title: "4X", description: "4X", value: 4),
			   .init(title: "5X", description: "5X", value: 5)
		   ],
		   defaultValue: 1)
		   }()
	static var msaaOption: CoreOption = {
		 .enumeration(.init(title: "Multi Sample Anti-Aliasing",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		   values: [
			   .init(title: "Disabled", description: "Disabled", value: 0),
			   .init(title: "2X", description: "2X", value: 1),
			   .init(title: "4X", description: "4X", value: 2),
			   .init(title: "8X", description: "8X", value: 3)
		   ],
		   defaultValue: 1)
		   }()

	static var fastMemoryOption: CoreOption = {
		.bool(.init(
			title: "Fast Memory (Requires Large Memory)",
			description: nil,
			requiresRestart: true),
		defaultValue: true)
	}()

	static var cpuOption: CoreOption = {
		 .enumeration(.init(title: "CPU Type",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		  values: [
			.init(title: "Interpreter", description: "Interpreter", value: 0),
			.init(title: "Just In Time", description: "Just In Time", value: 1),
			.init(title: "IR Just In Time", description: "IT Just In Time", value: 2)
		  ],
		  defaultValue: 0)
	}()

	public static var options: [CoreOption] {
		var options = [CoreOption]()
		let coreOptions: [CoreOption] = [
			resolutionOption, gsOption, textureAnisotropicOption,
			textureUpscaleTypeOption, textureUpscaleOption, textureFilterOption,
			msaaOption, fastMemoryOption, cpuOption,
            stretchDisplayOption]
		let coreGroup:CoreOption = .group(.init(title: "PPSSPP! Core",
												description: "Global options for PPSSPP!"),
										  subOptions: coreOptions)
		options.append(contentsOf: [coreGroup])
		return options
	}

    static var stretchDisplayOption: CoreOption = {
        .bool(.init(
            title: "Stretch Display Size",
            description: nil,
            requiresRestart: true),
        defaultValue: false)
    }()
}

@objc public extension PVPPSSPPCore {
	@objc var resolution: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.resolutionOption).asInt ?? 0
	}
	@objc var gs: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.gsOption).asInt ?? 0
	}
	@objc var ta: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.textureAnisotropicOption).asInt ?? 0
	}
	@objc var tutype: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.textureUpscaleTypeOption).asInt ?? 0
	}
	@objc var tu: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.textureUpscaleOption).asInt ?? 0
	}
	@objc var tf: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.textureFilterOption).asInt ?? 0
	}
	@objc var cpu: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.cpuOption).asInt ?? 0
	}
	@objc var msaaOption: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.msaaOption).asInt ?? 0
	}
	@objc var fastMemoryOption: Bool{
		PVPPSSPPCore.valueForOption(PVPPSSPPCore.fastMemoryOption).asBool
	}
    @objc var stretch: Bool{
        PVPPSSPPCore.valueForOption(PVPPSSPPCore.stretchDisplayOption).asBool
    }
	func parseOptions() {
		self.gsPreference = NSNumber(value: gs).int8Value
		self.resFactor = NSNumber(value: resolution).int8Value
		self.cpuType = NSNumber(value:cpu).int8Value
		self.taOption = NSNumber(value:ta).int8Value
		self.tuOption = NSNumber(value:tu).int8Value
		self.tutypeOption = NSNumber(value:tutype).int8Value
		self.tfOption = NSNumber(value:tf).int8Value
		self.msaa = NSNumber(value: msaaOption).int8Value
		self.fastMemory = fastMemoryOption
        self.stretchOption = stretch
	}
}

extension PVPPSSPPCore: GameWithCheat {
	@objc public func setCheat(
		code: String,
		type: String,
		codeType: String,
		cheatIndex: UInt8,
		enabled: Bool
	) -> Bool
	{
		do {
			NSLog("Calling setCheat %@ %@ %@", code, type, codeType)
			try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
			return true
		} catch let error {
			NSLog("Error setCheat \(error)")
			return false
		}
	}

	public var supportsCheatCode: Bool
	{
		return true
	}

	public var cheatCodeTypes: [String] {
		return [
			"Raw Address Value Pairs (PPSSPP CwCheat)",
		];
	}
}

