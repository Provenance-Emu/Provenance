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
    
    static var spuOption: CoreOption = {
         .enumeration(.init(title: "Sound Processing Unit Block Count",
               description: "(Smaller Value is more accurate)",
               requiresRestart: true),
           values: [
               .init(title: "20", description: "20", value: 20),
               .init(title: "100", description: "100", value: 100),
               .init(title: "200", description: "200", value: 200),
               .init(title: "1000", description: "1000", value: 1000),
               .init(title: "2000", description: "2000", value: 2000),
               .init(title: "5000", description: "5000", value: 5000),
               .init(title: "10000", description: "10000", value: 10000),
               .init(title: "30000", description: "30000", value: 30000),
               .init(title: "60000", description: "60000", value: 60000),
               .init(title: "120000", description: "120000", value: 120000),
               .init(title: "240000", description: "240000", value: 240000),
               .init(title: "1000000", description: "1000000", value: 1000000),
           ],
           defaultValue: 100)
           }()
    
    static var limitFPSOption: CoreOption = {
        .bool(.init(
            title: "Limit FPS to 60 FPS",
            description: nil,
            requiresRestart: true
        ), defaultValue: true)
    }()
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [resolutionOption, gsOption, forceBilinearFilteringOption, spuOption, limitFPSOption]
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
    @objc var spu: Int{
        PVPlayCore.valueForOption(PVPlayCore.spuOption).asInt ?? 0
    }
    @objc var fps: Bool {
        PVPlayCore.valueForOption(PVPlayCore.limitFPSOption).asBool
    }
    func parseOptions() {
        self.gsPreference = NSNumber(value: gs).int8Value
        self.resFactor = NSNumber(value: resolution).int8Value
        self.limitFPS = NSNumber(value:fps).boolValue
        self.spuCount=NSNumber(value:spu).int8Value
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

    public var supportsCheatCode: Bool
    {
        return true
    }

    public var cheatCodeTypes: [String] {
        return [
            "Code Breaker",
            "Game Shark V3",
            "Pro Action Replay V1",
            "Pro Action Replay V2",
            "Raw MemAddress:Value Pairs"
        ];
    }
}

