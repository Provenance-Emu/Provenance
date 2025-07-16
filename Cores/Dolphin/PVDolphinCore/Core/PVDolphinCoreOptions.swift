import Foundation
import PVSupport
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

@objc
public class PVDolphinCoreOptions: NSObject, CoreOptions {
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
			defaultValue: 1)
			}()

	static var gsOption: CoreOption = {
		 .enumeration(.init(title: "Graphics Handler",
			   description: "(Requires Restart)",
			   requiresRestart: true),
		  values: [
			   .init(title: "Vulkan", description: "Vulkan", value: 0),
			   .init(title: "OpenGL", description: "OpenGL", value: 1)
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
    
    static var enableCheatOption: CoreOption = {
        .bool(.init(
            title: "Enable Cheat Codes (Runs Slower)",
            description: nil,
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
		   defaultValue: 8)
		   }()

	static var ssaaOption: CoreOption = {
		.bool(.init(
			title: "Single Surface Anti-Aliasing",
			description: nil,
			requiresRestart: false),
		defaultValue: true)
	}()

	static var fastMemoryOption: CoreOption = {
		.bool(.init(
			title: "Fast Memory (Much Faster)",
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
			.init(title: "Cached Interpreter", description: "Cached Interpreter", value: 1),
			.init(title: "Just In Time", description: "Just In Time", value: 2)
		  ],
		  defaultValue: 1)
	}()

	static var cpuClockOption: CoreOption = {
	.enumeration(.init(title: "CPU Overclock",
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
    static var multiPlayerOption: CoreOption = {
        .bool(.init(
            title: MAP_MULTIPLAYER,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    static var volumeOption: CoreOption = {
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
                        .init(title: "9%", description: "9%", value: 9),
                        .init(title: "8%", description: "8%", value: 8),
                        .init(title: "7%", description: "7%", value: 7),
                        .init(title: "6%", description: "6%", value: 6),
                        .init(title: "5%", description: "5%", value: 5),
                        .init(title: "4%", description: "4%", value: 4),
                        .init(title: "3%", description: "3%", value: 3),
                        .init(title: "2%", description: "2%", value: 2),
                        .init(title: "1%", description: "1%", value: 1),
                        .init(title: "0%", description: "0%", value: 0),
                     ],
                     defaultValue: 100)
    }()
	public static var options: [CoreOption] {
		var options = [CoreOption]()
		let coreOptions: [CoreOption] = [
			resolutionOption, gsOption, forceBilinearFilteringOption,
			cpuOption, msaaOption, ssaaOption, cpuClockOption, volumeOption,
			fastMemoryOption, enableCheatOption, multiPlayerOption]
		let coreGroup:CoreOption = .group(.init(title: "Dolphin! Core",
												description: "Global options for Dolphin!"),
										  subOptions: coreOptions)
		options.append(contentsOf: [coreGroup])
		return options
	}
}

@objc public extension PVDolphinCoreOptions {
	@objc static var resolution: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.resolutionOption).asInt ?? 0
	}
	@objc static var gs: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.gsOption).asInt ?? 0
	}
	@objc static var bilinearFiltering: Bool {
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.forceBilinearFilteringOption).asBool
	}
	@objc static var cpu: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.cpuOption).asInt ?? 0
	}
	@objc static var cpuClock: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.cpuClockOption).asInt ?? 0
	}
    @objc static var enableCheat: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.enableCheatOption).asBool
    }
	@objc static var msaa: Int{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.msaaOption).asInt ?? 0
	}
	@objc static var ssaa: Bool{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.ssaaOption).asBool
	}
	@objc static var fastMemory: Bool{
		PVDolphinCore.valueForOption(PVDolphinCoreOptions.fastMemoryOption).asBool
	}
    @objc static var multiPlayer: Bool{
        PVDolphinCore.valueForOption(PVDolphinCoreOptions.multiPlayerOption).asBool
    }
}

@objc public extension PVDolphinCoreBridge {
    @objc func parseOptions() {
        self.gsPreference = NSNumber(value: PVDolphinCoreOptions.gs).int8Value
        self.resFactor = NSNumber(value: PVDolphinCoreOptions.resolution).int8Value
        self.cpuType = NSNumber(value:PVDolphinCoreOptions.cpu).int8Value
        self.isBilinear = PVDolphinCoreOptions.bilinearFiltering
        self.msaa = NSNumber(value: PVDolphinCoreOptions.msaa).int8Value
        self.ssaa = PVDolphinCoreOptions.ssaa
        if self.msaa < 2 {
            self.ssaa=false
        }
        self.enableCheatCode = PVDolphinCoreOptions.enableCheat
        self.fastMemory = PVDolphinCoreOptions.fastMemory
        self.cpuOClock = NSNumber(value: PVDolphinCoreOptions.cpuClock).int8Value
        self.multiPlayer = PVDolphinCoreOptions.multiPlayer
        self.volume = NSNumber(value: PVDolphinCoreOptions.valueForOption(PVDolphinCoreOptions.volumeOption).asInt ?? 100).int8Value;
    }
}
