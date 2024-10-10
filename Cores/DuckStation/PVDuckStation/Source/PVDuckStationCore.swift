//
//  PVDuckStationCore.swift
//  PVDuckStation
//
//  Created by Joseph Mattiello on 3/8/18.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore

@objc
@objcMembers
open class PVDuckStationCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Lifecycle
    
    let _bridge: PVDuckStationCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVDuckStationCore: PVPSXSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVDuckStationCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVDuckStationOptions.options
    }
}

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

    @objc
    public var supportsCheatCode: Bool {
        return false;
//        return self.getCheatSupport();
    }
}

