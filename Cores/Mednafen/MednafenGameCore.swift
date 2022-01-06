//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
import UIKit
// import PVMednafen.Private

extension MednafenGameCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        switch systemType {
        case .PSX:
            return numberOfDiscs > 1
        default:
            return false
        }
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

extension MednafenGameCore: CoreActions {
    public var coreActions: [CoreAction]? {
        switch systemType {
        case .virtualBoy:
            return [CoreAction(title: "Change Palette", options: nil)]
        default:
            return nil
        }
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case "Change Palette":
            changeDisplayMode()
        default:
            print("Unknown action: " + action.title)
        }
    }
}

extension MednafenGameCore: GameWithCheat {
    public func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
    {
        do {
            try self.setCheat(code, setType: type, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }
    
    public func supportsCheatCode() -> Bool
    {
        return self.getCheatSupport();
    }
}

extension MednafenGameCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()

		let fastGroup:CoreOption = .group(.init(title: "Fast Cores",
												description: "Alternative versions of cores that trade accuracy for speed"),
										  subOptions: [pceFastOption, snesFastOption])
        

        options.append(fastGroup)

        return options
    }()


    static var pceFastOption: CoreOption = {
		.bool(.init(
            title: "PCE Fast",
            description: "Use a faster but possibly buggy PCEngine version.",
            requiresRestart: true),
                                         defaultValue: false)
    }()

    static var snesFastOption: CoreOption = {
		.bool(.init(
            title: "SNES Fast",
            description: "Use faster but maybe more buggy SNES core (default)",
            requiresRestart: true), defaultValue: true)
    }()
}

@objc public extension MednafenGameCore {
    @objc(mednafen_pceFast) var mednafen_pceFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.pceFastOption).asBool }
    @objc(mednafen_snesFast) var mednafen_snesFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.snesFastOption).asBool }
}
