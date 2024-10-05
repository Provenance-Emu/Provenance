//
//  PVEmuThreeCore.swift
//  PVEmuThree
//
//  Created by Joseph Mattiello on 9/30/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVAudio
import PVEmulatorCore
#if canImport(GameController)
import GameController
#endif

@objc
@objcMembers
open class PVEmuThreeCore: PVEmulatorCore, @unchecked Sendable {

    let _bridge: PVEmuThreeCoreBridge = .init()
    
    // MARK: Audio

    // MARK: Queues
   
    // MARK: Controls

    // MARK: Videe

    // MARK: Lifecycle

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVEmuThreeCore: PV3DSSystemResponderClient {
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: PVCoreBridge.PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    
    public func didPush(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVEmuThreeCore: GameWithCheat {
    @objc public func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool
    ) -> Bool
    {
        do {
            NSLog("Calling setCheat \(code) \(type) \(codeType)")
            try _bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
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
            "Gateway",
        ];
    }
}

extension PVEmuThreeCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVEmuThreeCoreOptions.options
    }
}
