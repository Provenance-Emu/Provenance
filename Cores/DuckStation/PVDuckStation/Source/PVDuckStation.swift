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
