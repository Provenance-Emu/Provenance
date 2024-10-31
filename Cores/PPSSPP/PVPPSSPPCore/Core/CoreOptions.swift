import Foundation
import PVEmulatorCore;
import PVCoreBridge;
import PVCoreObjCBridge;

extension PVPPSSPPCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVPPSSPPCoreOptions.options
    }
}

@objc
public class PVPPSSPPCoreOptions: NSObject, CoreOptions {
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
                     defaultValue: 3)
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
    static var stretchDisplayOption: CoreOption = {
        .bool(.init(
            title: "Stretch Display Size",
            description: nil,
            requiresRestart: true),
              defaultValue: false)
    }()
    static var volumeOption: CoreOption = {
        .enumeration(.init(title: "Audio Volume",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "100%", description: "100%", value: 10),
                        .init(title: "90%", description: "90%", value: 9),
                        .init(title: "80%", description: "80%", value: 8),
                        .init(title: "70%", description: "70%", value: 7),
                        .init(title: "60%", description: "60%", value: 6),
                        .init(title: "50%", description: "50%", value: 5),
                        .init(title: "40%", description: "40%", value: 4),
                        .init(title: "30%", description: "30%", value: 3),
                        .init(title: "20%", description: "20%", value: 2),
                        .init(title: "10%", description: "10%", value: 1),
                        .init(title: "0%", description: "0%", value: 0),
                     ],
                     defaultValue: 10)
    }()
    static var buttonPrefOption: CoreOption = {
        .enumeration(.init(title: "Confirmation Button",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "Circle", description: "Circle", value: 0),
                        .init(title: "Cross", description: "Cross", value: 1),
                     ],
                     defaultValue: 1)
    }()

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [
            resolutionOption, gsOption, textureAnisotropicOption,
            textureUpscaleTypeOption, textureUpscaleOption, textureFilterOption,
            msaaOption, fastMemoryOption, cpuOption,
            stretchDisplayOption, volumeOption, buttonPrefOption]
        let coreGroup:CoreOption = .group(.init(title: "PPSSPP! Core",
                                                description: "Global options for PPSSPP!"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }    
}

@objc public extension PVPPSSPPCoreOptions {
	@objc static var resolution: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.resolutionOption).asInt ?? 0
	}
	@objc static var gs: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.gsOption).asInt ?? 0
	}
	@objc static var ta: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.textureAnisotropicOption).asInt ?? 0
	}
	@objc static var tutype: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.textureUpscaleTypeOption).asInt ?? 0
	}
	@objc static var tu: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.textureUpscaleOption).asInt ?? 0
	}
	@objc static var tf: Int {
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.textureFilterOption).asInt ?? 0
	}
	@objc static var cpu: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.cpuOption).asInt ?? 0
	}
	@objc static var msaa: Int{
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.msaaOption).asInt ?? 0
	}
	@objc static var fastMemory: Bool{
		PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.fastMemoryOption).asBool
	}
    @objc static var stretch: Bool{
        PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.stretchDisplayOption).asBool
    }
    @objc var buttonPrefOption: Int{
        PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.buttonPrefOption).asInt ?? 0
    }
}

extension PVPPSSPPCoreBridge {
    func parseOptions() {
        self.gsPreference = NSNumber(value: PVPPSSPPCoreOptions.gs).int8Value
        self.resFactor = NSNumber(value: PVPPSSPPCoreOptions.resolution).int8Value
        self.cpuType = NSNumber(value:PVPPSSPPCoreOptions.cpu).int8Value
        self.taOption = NSNumber(value:PVPPSSPPCoreOptions.ta).int8Value
        self.tuOption = NSNumber(value:PVPPSSPPCoreOptions.tu).int8Value
        self.tutypeOption = NSNumber(value:PVPPSSPPCoreOptions.tutype).int8Value
        self.tfOption = NSNumber(value:PVPPSSPPCoreOptions.tf).int8Value
        self.msaa = NSNumber(value:PVPPSSPPCoreOptions.msaa).int8Value
        self.fastMemory = PVPPSSPPCoreOptions.fastMemory
        self.stretchOption = PVPPSSPPCoreOptions.stretch
        self.volume = NSNumber(value: PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.volumeOption).asInt ?? 0).int32Value
        self.buttonPref = NSNumber(value: PVPPSSPPCore.valueForOption(PVPPSSPPCoreOptions.buttonPrefOption).asInt ?? 0).int8Value
    }
}

extension PVPPSSPPCoreBridge: GameWithCheat {
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

