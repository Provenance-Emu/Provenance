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
               .init(title: "22", description: "22", value: 22),
               .init(title: "100", description: "100", value: 100),
               .init(title: "222", description: "222", value: 222),
           ],
           defaultValue: 100)
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
    static var limitFPSOption: CoreOption = {
        .bool(.init(
            title: "Limit FPS to 60 FPS",
            description: nil,
            requiresRestart: true
        ), defaultValue: true)
    }()
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [resolutionOption, gsOption, forceBilinearFilteringOption, spuOption, limitFPSOption, volumeOption]
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
        self.spuCount = NSNumber(value:spu).int8Value
        self.volume = NSNumber(value:PVPlayCore.valueForOption(PVPlayCore.volumeOption).asInt ?? 100).int8Value
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

