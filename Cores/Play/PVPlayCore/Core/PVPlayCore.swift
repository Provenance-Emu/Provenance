import Foundation

extension PVPlayCore: CoreOptional {
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
               .init(title: "OpenGL", description: "OpenGL", value: 0),
               .init(title: "Vulkan", description: "Vulkan (Experimental)", value: 1)
          ],
          defaultValue: 0)
    }()
    
    static var forceBilinearFilteringOption: CoreOption = {
        .bool(.init(
            title: "Enable bilinear filtering.",
            description: nil,
            requiresRestart: false))
    }()
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [resolutionOption, gsOption, forceBilinearFilteringOption]
        let coreGroup:CoreOption = .group(.init(title: "Play! Core",
                                                description: "Global options for Play!"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVPlayCore {
    @objc var resolution: Int{
        PVPlayCore.valueForOption(PVPlayCore.resolutionOption).asInt ?? 0
    }
    @objc var gs: Int{
        PVPlayCore.valueForOption(PVPlayCore.gsOption).asInt ?? 0
    }
    @objc var bilinearFiltering: Bool {
        PVPlayCore.valueForOption(PVPlayCore.forceBilinearFilteringOption).asBool
    }
    func parseOptions() {
        self.gsPreference = NSNumber(value: gs).int8Value
        self.resFactor = NSNumber(value: resolution).int8Value
    }
}

extension PVPlayCore: GameWithCheat {
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

    public func supportsCheatCode() -> Bool
    {
        return true
    }

    public func cheatCodeTypes() -> NSArray {
        return [
            "Code Breaker",
            "Game Shark V3",
            "Pro Action Replay V1",
            "Pro Action Replay V2",
            "Raw MemAddress:Value Pairs"
        ];
    }
}

