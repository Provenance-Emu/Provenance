import Foundation
extension PVRetroArchCore: CoreOptional {
    static var gsOption: CoreOption = {
         .enumeration(.init(title: "Graphics Handler",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "Metal", description: "Metal", value: 0),
               .init(title: "OpenGL", description: "OpenGL", value: 1),
               .init(title: "Vulkan", description: "Vulkan", value: 2)
          ],
          defaultValue: 0)
    }()
    
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [gsOption]
        let coreGroup:CoreOption = .group(.init(title: "RetroArch Core",
                                                description: "Override options for RetroArch Core"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVRetroArchCore {
    @objc var gs: Int{
        PVRetroArchCore.valueForOption(PVRetroArchCore.gsOption).asInt ?? 0
    }
    func parseOptions() {
        self.gsPreference = NSNumber(value: gs).int8Value
    }
}
extension PVRetroArchCore: GameWithCheat {
	@objc public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
		do {
			ILOG("Calling setCheat \(code) \(type) \(codeType)")
			try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
			return true
		} catch let error {
			ILOG("Error setCheat \(error)")
			return false
		}
	}
    @objc
    public var supportsCheatCode: Bool { return true }
    @objc
    public var cheatCodeTypes: [String] { return [] }
}
