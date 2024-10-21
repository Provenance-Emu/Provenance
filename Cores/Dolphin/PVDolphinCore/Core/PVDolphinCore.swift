//
//  PVDolphinCore.swift
//  PVDolphin
//
//  Created by Joseph Mattiello on 10/8/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore

@objc
@objcMembers
open class PVDolphinCore: PVEmulatorCore, @unchecked Sendable {
    // MARK: Lifecycle
    
    let _bridge: PVDolphinCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVDolphinCore: PVWiiSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVWiiMoteButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVDolphinCore: PVGameCubeSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVGCButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}

extension PVDolphinCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVDolphinCoreOptions.options
    }
}

extension PVDolphinCore: GameWithCheat {
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
            try self._bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
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
            "Gecko",
            "Pro Action Replay",
        ];
    }
}

