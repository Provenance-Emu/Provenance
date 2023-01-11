//
//  PVDuckStationCore.swift
//  PVDuckStation
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
import Foundation

extension PVDuckStationCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        return numberOfDiscs > 1
    }

    public func swapDisc(number: UInt) {
        setPauseEmulation(false)

        let index = number - 1
        setMedia(true, forDisc: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setMedia(false, forDisc: index)
        }
    }
}

//extension PVDuckStationCore: CoreActions {
//    public var coreActions: [CoreAction]? {
//        return nil
//    }
//
//    public func selected(action: CoreAction) {
//        switch action.title {
//        case "Change Palette":
//            changeDisplayMode()
//        default:
//            print("Unknown action: " + action.title)
//        }
//    }
//}

extension PVDuckStationCore: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try self.setCheat(code, setType: type, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([.gameShark])
    }
    
    public var supportsCheatCode: Bool {
        return self.getCheatSupport();
    }
}

extension PVDuckStationCore: CoreOptional {

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

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [gsOption]
        let coreGroup:CoreOption = .group(.init(title: "DuckStation Core",
                                                description: "Global options for DuckStation"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVDuckStationCore {
    @objc var gs: Int{
        PVDuckStationCore.valueForOption(PVDuckStationCore.gsOption).asInt ?? 0
    }

//    func parseOptions() {
//        self.gsPreference = NSNumber(value: gs).int8Value
//    }
}
