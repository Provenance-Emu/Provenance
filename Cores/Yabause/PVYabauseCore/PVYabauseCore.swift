//
//  PVEP128EmuCore.swift
//  PVEP128EmuCore
//
//  Created by Joseph Mattiello on 10/06/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVYabauseCore: PVEmulatorCore {

    let _bridge: PVYabauseCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVYabauseCore: PVSaturnSystemResponderClient {
    /// Resolve the bridge to a Saturn responder. Logs and traps in debug builds when
    /// the bridge does not conform — this catches missing protocol implementations
    /// during development rather than silently no-oping or crashing on a force cast.
    private var saturnResponder: PVSaturnSystemResponderClient? {
        guard let responder = _bridge as? PVSaturnSystemResponderClient else {
            assertionFailure("PVYabauseCoreBridge does not conform to PVSaturnSystemResponderClient — Saturn input will be ignored.")
            return nil
        }
        return responder
    }

    public func didMoveJoystick(_ button: PVCoreBridge.PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        saturnResponder?.didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        saturnResponder?.didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        saturnResponder?.didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        saturnResponder?.didRelease(button, forPlayer: player)
    }
}
